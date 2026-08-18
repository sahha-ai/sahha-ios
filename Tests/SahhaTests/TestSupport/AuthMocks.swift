import Foundation
@testable import Sahha

// MARK: - JWT fixtures

/// Builds a signed-looking (unverified) JWT whose payload contains the given claims.
func encodeJWT(payload: [String: Any]) -> String {
    func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    let header = base64URL(Data(#"{"alg":"HS256","typ":"JWT"}"#.utf8))
    let body = base64URL(try! JSONSerialization.data(withJSONObject: payload))
    return "\(header).\(body).signature"
}

/// A JWT whose `exp` claim is `expiresIn` seconds from now (negative = already expired).
func jwt(expiresIn: TimeInterval) -> String {
    encodeJWT(payload: ["exp": Date().timeIntervalSince1970 + expiresIn])
}

// MARK: - Auth service

/// Records authenticate/refresh calls and answers them from per-call scripts: call N
/// consumes script element N, and the last element repeats once the script is
/// exhausted. The single-answer convenience init preserves the original
/// TokenRefreshTests double's behavior (refresh answers it; authenticate is unscripted
/// and throws).
actor MockAuthService: AuthServiceProtocol {
    typealias Script = @Sendable () throws -> TokenResponse

    private let authenticateScript: [Script]
    private let refreshScript: [Script]
    private let delayNanos: UInt64

    private(set) var authenticateCallCount = 0
    private(set) var lastAuthenticateExternalId: String?
    private(set) var refreshCallCount = 0
    private(set) var lastRefreshToken: String?

    init(
        delayNanos: UInt64 = 0,
        authenticate: [Script] = [],
        refresh: [Script] = []
    ) {
        self.delayNanos = delayNanos
        self.authenticateScript = authenticate
        self.refreshScript = refresh
    }

    init(delayNanos: UInt64 = 0, success: TokenResponse? = nil, failure: APIErrorResponse? = nil) {
        let step: Script
        if let failure {
            step = { throw failure }
        } else if let success {
            step = { success }
        } else {
            step = { throw SahhaError(message: "MockAuthService not configured") }
        }
        self.init(delayNanos: delayNanos, refresh: [step])
    }

    func authenticate(appId: String, appSecret: String, externalId: String) async throws -> TokenResponse {
        authenticateCallCount += 1
        lastAuthenticateExternalId = externalId
        // Propagates cancellation, so dispose-mid-flight tests exercise the real path.
        if delayNanos > 0 { try await Task.sleep(nanoseconds: delayNanos) }
        guard let step = step(in: authenticateScript, callIndex: authenticateCallCount - 1) else {
            throw SahhaError(message: "authenticate is not scripted in MockAuthService")
        }
        return try step()
    }

    func refreshToken(refreshToken: String) async throws -> TokenResponse {
        refreshCallCount += 1
        lastRefreshToken = refreshToken
        // Propagates cancellation, so dispose-mid-flight tests exercise the real path.
        if delayNanos > 0 { try await Task.sleep(nanoseconds: delayNanos) }
        guard let step = step(in: refreshScript, callIndex: refreshCallCount - 1) else {
            throw SahhaError(message: "refreshToken is not scripted in MockAuthService")
        }
        return try step()
    }

    private func step(in script: [Script], callIndex: Int) -> Script? {
        guard !script.isEmpty else { return nil }
        return script[min(callIndex, script.count - 1)]
    }
}

// MARK: - Token stores

/// In-memory token store (no keychain, no global authSnapshot).
actor MockTokenStore: TokenStoreProtocol {
    private var current: TokenResponse?
    private(set) var saveCount = 0
    private(set) var clearCount = 0
    private(set) var disposed = false

    init(_ initial: TokenResponse?) { self.current = initial }

    func saveToken(_ token: TokenResponse) throws {
        saveCount += 1
        current = token
    }
    func token() -> TokenResponse? { current }
    func profileToken() -> String? { current?.profileToken }
    func refreshToken() -> String? { current?.refreshToken }
    func clearToken() {
        clearCount += 1
        current = nil
    }
    func dispose() async {
        current = nil
        disposed = true
    }
}

/// Returns a scripted sequence from `token()`, reproducing the exact
/// read→check→(rotated by another flight)→re-read interleaving the single-flight guard closes.
actor ScriptedTokenStore: TokenStoreProtocol {
    private var scripted: [TokenResponse?]
    private var current: TokenResponse?

    init(reads: [TokenResponse?]) {
        scripted = reads
        current = reads.last ?? nil
    }

    func token() -> TokenResponse? {
        scripted.isEmpty ? current : scripted.removeFirst()
    }
    func saveToken(_ token: TokenResponse) throws { current = token }
    func profileToken() -> String? { current?.profileToken }
    func refreshToken() -> String? { current?.refreshToken }
    func clearToken() { current = nil }
    func dispose() async { current = nil }
}

// MARK: - Auth manager

/// Stub AuthManager for interceptor-style tests, with optional injected failures.
actor MockAuthManager: AuthManagerProtocol {
    private let validToken: String
    private let refreshedToken: String
    private let getValidError: Error?
    private let refreshError: Error?
    private(set) var getValidCalls = 0
    private(set) var refreshStaleTokens: [String] = []

    init(
        validToken: String,
        refreshedToken: String,
        getValidError: Error? = nil,
        refreshError: Error? = nil
    ) {
        self.validToken = validToken
        self.refreshedToken = refreshedToken
        self.getValidError = getValidError
        self.refreshError = refreshError
    }

    func authenticate(appId: String, appSecret: String, externalId: String) async throws {}
    func authenticate(profileToken: String, refreshToken: String) async throws {}

    func getValidProfileToken() async throws -> String {
        getValidCalls += 1
        if let getValidError { throw getValidError }
        return validToken
    }

    func refreshProfileToken(staleToken: String) async throws -> String {
        refreshStaleTokens.append(staleToken)
        if let refreshError { throw refreshError }
        return refreshedToken
    }

    func hasValidProfileToken() async -> Bool { true }
}
