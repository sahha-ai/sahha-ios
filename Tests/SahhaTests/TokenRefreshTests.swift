import Testing
import Foundation
@testable import Sahha

/// Regression coverage for profile-token refresh.
///
/// Guards, in rough order of subtlety:
/// - the proactive path: an expired (or offset-window, or unparseable) profile token is
///   refreshed with the stored refresh token and the rotated pair persisted;
/// - the single-flight window: concurrent callers share ONE network refresh, the rotated pair
///   is saved INSIDE the flight (before any waiter resumes — `saveCount == 1`), and a caller
///   whose token was rotated mid-check reuses the stored token instead of burning the rotated
///   refresh token (the read→check→refresh→save TOCTOU);
/// - the terminal/transient split: dead-session verdicts (locally expired/unparseable refresh
///   token, HTTP 401/403) clear the session and surface the distinct "Session expired" error,
///   while network/5xx/uncorroborated-4xx failures keep tokens for a later retry. The local
///   refresh-token `exp` check matters because today's server returns 400 — not 401 — for an
///   expired refresh token;
/// - the reactive interceptor: a 401'd authed request forces exactly one refresh and one
///   retry; nothing else (4xx/5xx/transport errors) triggers a refresh or replays a request.
///
/// The auth doubles live in TestSupport/AuthMocks.swift; no test touches process-global or
/// persisted state (the real `TokenStore` — the one writer of the keychain session and the
/// persisted profileId — is never constructed here), so the file is safe under parallel
/// suite execution.

// MARK: - Helpers

private func okResponse() -> HTTPURLResponse {
    HTTPURLResponse(url: URL(string: "https://sandbox-api.sahha.ai")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
}

private func apiError(_ statusCode: Int) -> APIErrorResponse {
    APIErrorResponse(title: "HTTP \(statusCode)", statusCode: statusCode, location: "test", errors: [])
}

// MARK: - Mocks

/// Captures the requests an interceptor forwards and replies per call index.
private actor NextRecorder {
    private var requestLog: [APIRequest] = []
    private let responder: @Sendable (Int) throws -> APIResponse

    init(responder: @escaping @Sendable (Int) throws -> APIResponse) {
        self.responder = responder
    }

    func handle(_ request: APIRequest) async throws -> APIResponse {
        let index = requestLog.count
        requestLog.append(request)
        return try responder(index)
    }

    var callCount: Int { requestLog.count }
    var requests: [APIRequest] { requestLog }
}

// MARK: - JWT.isExpired

@Suite("JWT.isExpired")
struct JWTIsExpiredTests {
    @Test("Far-future token is valid")
    func farFutureValid() {
        #expect(JWT.isExpired(jwt(expiresIn: 3600)) == false)
    }

    @Test("Already-expired token is expired")
    func pastExpired() {
        #expect(JWT.isExpired(jwt(expiresIn: -10)) == true)
    }

    @Test("Offset keeps a comfortably-valid token valid")
    func offsetStillValid() {
        // exp = now + 1h, offset 30m → effective expiry now + 30m → still valid.
        #expect(JWT.isExpired(jwt(expiresIn: 3600), offset: .minutes(30)) == false)
    }

    @Test("Offset treats a soon-to-expire token as expired")
    func offsetWithinWindow() {
        // exp = now + 1m, offset 30m → effective expiry already passed → expired.
        #expect(JWT.isExpired(jwt(expiresIn: 60), offset: .minutes(30)) == true)
    }

    @Test("Missing exp claim is treated as expired")
    func missingExp() {
        #expect(JWT.isExpired(encodeJWT(payload: ["sub": "no-exp"])) == true)
    }

    @Test("Malformed tokens are treated as expired")
    func malformed() {
        #expect(JWT.isExpired("not.a.jwt") == true)
        #expect(JWT.isExpired("") == true)
        #expect(JWT.isExpired("only-one-part") == true)
    }
}

// MARK: - AuthManager refresh behaviour

@Suite("AuthManager token refresh")
struct AuthManagerRefreshTests {
    /// Margins are all ≥ 29 minutes from any decision boundary, so nothing here is
    /// wall-clock sensitive.
    private let validRefreshJWT = jwt(expiresIn: 86_400)
    private let rotatedRefreshJWT = jwt(expiresIn: 172_800)

    private func make(
        token: TokenResponse?,
        service: MockAuthService,
        expiryOffset: TimeInterval = .minutes(30)
    ) -> (AuthManager, MockTokenStore) {
        let store = MockTokenStore(token)
        let manager = AuthManager(
            authService: service,
            tokenStore: store,
            logger: NoopErrorLogger(),
            expiryOffset: expiryOffset
        )
        return (manager, store)
    }

    @Test("Expired profile token is refreshed with the stored refresh token and persisted")
    func expiredTriggersRefresh() async throws {
        let freshToken = jwt(expiresIn: 3600)
        let service = MockAuthService(success: TokenResponse(profileToken: freshToken, refreshToken: rotatedRefreshJWT))
        let (manager, store) = make(
            token: TokenResponse(profileToken: jwt(expiresIn: -10), refreshToken: validRefreshJWT),
            service: service
        )

        let result = try await manager.getValidProfileToken()

        #expect(result == freshToken)
        #expect(await service.refreshCallCount == 1)
        #expect(await service.lastRefreshToken == validRefreshJWT)      // used the STORED refresh token
        #expect(await store.token()?.profileToken == freshToken)        // rotated tokens persisted
        #expect(await store.token()?.refreshToken == rotatedRefreshJWT)
        #expect(await store.saveCount == 1)
    }

    @Test("A token expiring inside the expiry offset is refreshed")
    func withinOffsetTriggersRefresh() async throws {
        let service = MockAuthService(success: TokenResponse(profileToken: jwt(expiresIn: 3600), refreshToken: rotatedRefreshJWT))
        let (manager, _) = make(
            token: TokenResponse(profileToken: jwt(expiresIn: 60), refreshToken: validRefreshJWT),
            service: service,
            expiryOffset: .minutes(30)
        )

        _ = try await manager.getValidProfileToken()

        #expect(await service.refreshCallCount == 1)
    }

    @Test("A still-valid token is returned without refreshing")
    func validTokenSkipsRefresh() async throws {
        let validToken = jwt(expiresIn: 3600)
        let service = MockAuthService(failure: apiError(401))   // must never be called
        let (manager, _) = make(
            token: TokenResponse(profileToken: validToken, refreshToken: validRefreshJWT),
            service: service
        )

        let result = try await manager.getValidProfileToken()

        #expect(result == validToken)
        #expect(await service.refreshCallCount == 0)
    }

    @Test(
        "A locally dead refresh token is terminal before any network call",
        arguments: ["not-a-jwt", jwt(expiresIn: -300)]
    )
    func preflightDeadRefreshToken(deadRefreshToken: String) async throws {
        let service = MockAuthService(failure: apiError(401))   // must never be called
        let (manager, store) = make(
            token: TokenResponse(profileToken: jwt(expiresIn: -10), refreshToken: deadRefreshToken),
            service: service
        )

        let error = await #expect(throws: SahhaError.self) {
            _ = try await manager.getValidProfileToken()
        }

        // Today's server answers an expired refresh token with HTTP 400, so the dead-session
        // verdict must come from the token's own exp claim — with zero network calls.
        #expect(error?.message == AuthManager.sessionExpiredMessage)
        #expect(await service.refreshCallCount == 0)
        #expect(await store.clearCount == 1)
        #expect(await store.token() == nil)
        #expect(await manager.hasValidProfileToken() == false)
    }

    @Test("A rejected refresh token (401) clears the session and re-authentication recovers")
    func deadRefreshTokenClearsSession() async throws {
        let service = MockAuthService(failure: apiError(401))
        let (manager, store) = make(
            token: TokenResponse(profileToken: jwt(expiresIn: -10), refreshToken: validRefreshJWT),
            service: service
        )

        let error = await #expect(throws: SahhaError.self) {
            _ = try await manager.getValidProfileToken()
        }

        #expect(error?.message == AuthManager.sessionExpiredMessage)
        #expect((error?.error as? APIErrorResponse)?.statusCode == 401)  // cause preserved
        #expect(await store.token() == nil)
        #expect(await store.clearCount == 1)
        #expect(await store.disposed == false)                           // store still usable
        #expect(await manager.hasValidProfileToken() == false)

        // The cleared store must accept a fresh session (clearToken is not a teardown).
        try await manager.authenticate(profileToken: jwt(expiresIn: 3600), refreshToken: validRefreshJWT)
        #expect(await manager.hasValidProfileToken() == true)
    }

    @Test("A 403 from the refresh endpoint is terminal")
    func forbiddenIsTerminal() async throws {
        let service = MockAuthService(failure: apiError(403))
        let (manager, store) = make(
            token: TokenResponse(profileToken: jwt(expiresIn: -10), refreshToken: validRefreshJWT),
            service: service
        )

        let error = await #expect(throws: SahhaError.self) {
            _ = try await manager.getValidProfileToken()
        }

        #expect(error?.message == AuthManager.sessionExpiredMessage)
        #expect(await store.token() == nil)
    }

    @Test(
        "Failures with a locally valid refresh token keep the session for a later retry",
        arguments: [400, 404, 408, 429, 500, -1]
    )
    func uncorroboratedFailureKeepsTokens(statusCode: Int) async throws {
        let service = MockAuthService(failure: apiError(statusCode))
        let (manager, store) = make(
            token: TokenResponse(profileToken: jwt(expiresIn: -10), refreshToken: validRefreshJWT),
            service: service
        )

        // Not wrapped: transient failures surface the raw APIErrorResponse.
        await #expect(throws: APIErrorResponse.self) {
            _ = try await manager.getValidProfileToken()
        }

        // 400 is what today's server returns for dead refresh tokens — but it is also what a
        // malformed request produces, so without local corroboration it must NOT clear the
        // session (a client bug would otherwise sign out the entire fleet).
        #expect(await store.token() != nil)
        #expect(await store.clearCount == 0)
        #expect(await store.token()?.refreshToken == validRefreshJWT)
    }

    @Test("Concurrent expired-token callers share a single refresh and a single save")
    func concurrentRefreshIsDeduplicated() async throws {
        let freshToken = jwt(expiresIn: 3600)
        let service = MockAuthService(
            delayNanos: 200_000_000,                         // 200ms so callers overlap
            success: TokenResponse(profileToken: freshToken, refreshToken: rotatedRefreshJWT)
        )
        let (manager, store) = make(
            token: TokenResponse(profileToken: jwt(expiresIn: -10), refreshToken: validRefreshJWT),
            service: service
        )

        let results: [String?] = await withTaskGroup(of: String?.self) { group in
            for _ in 0..<10 {
                group.addTask { try? await manager.getValidProfileToken() }
            }
            var collected: [String?] = []
            for await result in group { collected.append(result) }
            return collected
        }

        #expect(results.count == 10)
        #expect(results.allSatisfy { $0 == freshToken })
        #expect(await service.refreshCallCount == 1)
        // Persisted INSIDE the single flight — not once per waiter (the pre-fix behavior).
        #expect(await store.saveCount == 1)
        #expect(await store.token()?.profileToken == freshToken)
    }

    @Test("Concurrent callers on a failing flight share one refresh and one session clear")
    func failingFlightCoalesces() async throws {
        let service = MockAuthService(delayNanos: 200_000_000, failure: apiError(401))
        let (manager, store) = make(
            token: TokenResponse(profileToken: jwt(expiresIn: -10), refreshToken: validRefreshJWT),
            service: service
        )

        let errors: [Error] = await withTaskGroup(of: Error?.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    do { _ = try await manager.getValidProfileToken(); return nil } catch { return error }
                }
            }
            var collected: [Error] = []
            for await error in group { if let error { collected.append(error) } }
            return collected
        }

        // Every caller fails with a SahhaError (session-expired from the shared flight, or
        // unauthenticated if it read the store after the clear), never a partial success.
        #expect(errors.count == 10)
        #expect(errors.allSatisfy { $0 is SahhaError })
        #expect(errors.contains { ($0 as? SahhaError)?.message == AuthManager.sessionExpiredMessage })
        #expect(await service.refreshCallCount == 1)
        #expect(await store.clearCount == 1)
    }

    @Test("A proactive caller whose token was rotated mid-check reuses the stored token")
    func proactiveRefreshSkipsNetworkWhenStoreRotatedMidCheck() async throws {
        let rotated = jwt(expiresIn: 3600)
        let service = MockAuthService(failure: apiError(401))      // must never be called
        let store = ScriptedTokenStore(reads: [
            TokenResponse(profileToken: jwt(expiresIn: -10), refreshToken: validRefreshJWT),  // outer isExpired check
            TokenResponse(profileToken: rotated, refreshToken: rotatedRefreshJWT),            // re-read inside the flight
        ])
        let manager = AuthManager(authService: service, tokenStore: store, logger: NoopErrorLogger())

        // Pre-fix code burns the first (already-rotated) refresh token here and throws.
        #expect(try await manager.getValidProfileToken() == rotated)
        #expect(await service.refreshCallCount == 0)
    }

    @Test("refreshProfileToken is idempotent once another caller has already rotated the token")
    func reactiveRefreshIsIdempotent() async throws {
        let currentToken = jwt(expiresIn: 3600)
        let service = MockAuthService(failure: apiError(401))    // must never be called
        let (manager, _) = make(
            token: TokenResponse(profileToken: currentToken, refreshToken: rotatedRefreshJWT),
            service: service
        )

        // The server rejected an older token, but the store already holds a newer one.
        let result = try await manager.refreshProfileToken(staleToken: jwt(expiresIn: -10))

        #expect(result == currentToken)
        #expect(await service.refreshCallCount == 0)
    }

    @Test("The reuse-stored-token branch rejects an expired stored token and refreshes instead")
    func bypassRejectsExpiredStoredToken() async throws {
        let freshToken = jwt(expiresIn: 3600)
        let service = MockAuthService(success: TokenResponse(profileToken: freshToken, refreshToken: rotatedRefreshJWT))
        let (manager, _) = make(
            token: TokenResponse(profileToken: jwt(expiresIn: -10), refreshToken: validRefreshJWT),
            service: service
        )

        // Stale token differs from the stored one, but the stored one is itself expired —
        // handing it back would just bounce off the server again.
        let result = try await manager.refreshProfileToken(staleToken: jwt(expiresIn: -20))

        #expect(result == freshToken)
        #expect(await service.refreshCallCount == 1)
    }

    @Test("A freshly minted token rejected by the server is not immediately re-rotated")
    func reactiveRefreshIsPaced() async throws {
        let mintedToken = jwt(expiresIn: 3600)
        let service = MockAuthService(success: TokenResponse(profileToken: mintedToken, refreshToken: rotatedRefreshJWT))
        let (manager, _) = make(
            token: TokenResponse(profileToken: jwt(expiresIn: -10), refreshToken: validRefreshJWT),
            service: service
        )

        // Proactive refresh mints a token…
        #expect(try await manager.getValidProfileToken() == mintedToken)
        #expect(await service.refreshCallCount == 1)

        // …and a server 401 on that just-minted token must not burn another rotation: the
        // rejection is for a non-credential reason, so hand the token back and let the retry's
        // failure propagate.
        let result = try await manager.refreshProfileToken(staleToken: mintedToken)

        #expect(result == mintedToken)
        #expect(await service.refreshCallCount == 1)
    }

    @Test("An empty store fails both entry points without touching the network")
    func emptyStoreThrowsUnauthenticated() async throws {
        let service = MockAuthService(failure: apiError(401))   // must never be called
        let (manager, _) = make(token: nil, service: service)

        let getValidError = await #expect(throws: SahhaError.self) {
            _ = try await manager.getValidProfileToken()
        }
        let refreshError = await #expect(throws: SahhaError.self) {
            _ = try await manager.refreshProfileToken(staleToken: "anything")
        }

        #expect(getValidError?.message == "Unauthorized. Please call `Sahha.authenticate(...)` first.")
        #expect(refreshError?.message == getValidError?.message)
        #expect(await service.refreshCallCount == 0)
        #expect(await manager.hasValidProfileToken() == false)
    }

    @Test("Disposing mid-flight cancels the refresh without saving or clearing tokens")
    func disposeDuringFlightIsTransient() async throws {
        let original = TokenResponse(profileToken: jwt(expiresIn: -10), refreshToken: validRefreshJWT)
        let service = MockAuthService(
            delayNanos: 2_000_000_000,   // long enough that dispose always lands mid-flight
            success: TokenResponse(profileToken: jwt(expiresIn: 3600), refreshToken: rotatedRefreshJWT)
        )
        let (manager, store) = make(token: original, service: service)

        let flight = Task { try await manager.getValidProfileToken() }
        // Wait until the network call has actually started before cancelling.
        for _ in 0..<10_000 {
            if await service.refreshCallCount > 0 { break }
            await Task.yield()
        }
        await manager.dispose()

        await #expect(throws: (any Error).self) { _ = try await flight.value }
        // Cancellation is transient: nothing saved, nothing cleared — a later attempt (or a
        // full deauthentication) decides the session's fate, not a torn-down flight.
        #expect(await store.saveCount == 0)
        #expect(await store.clearCount == 0)
        #expect(await store.token()?.refreshToken == validRefreshJWT)
    }
}

// MARK: - AuthorizationInterceptor

@Suite("AuthorizationInterceptor")
struct AuthorizationInterceptorTests {
    @Test("Requests that do not require auth pass through without a token")
    func passesThroughUnauthenticated() async throws {
        let authManager = MockAuthManager(validToken: "tok", refreshedToken: "tok-2")
        let interceptor = AuthorizationInterceptor(authManager: authManager)
        let recorder = NextRecorder { _ in (Data(), okResponse()) }

        let request = APIRequest(endpoint: "v1/public", requiresAuth: false)
        let (_, response) = try await interceptor.intercept(request: request) { try await recorder.handle($0) }

        #expect(response.statusCode == 200)
        #expect(await recorder.callCount == 1)
        #expect(await recorder.requests.first?.headers?["Authorization"] == nil)
        #expect(await authManager.getValidCalls == 0)
    }

    @Test("Authed requests get a Profile token header")
    func attachesProfileHeader() async throws {
        let authManager = MockAuthManager(validToken: "tok", refreshedToken: "tok-2")
        let interceptor = AuthorizationInterceptor(authManager: authManager)
        let recorder = NextRecorder { _ in (Data(), okResponse()) }

        let request = APIRequest(endpoint: "v1/profile/score", requiresAuth: true)
        _ = try await interceptor.intercept(request: request) { try await recorder.handle($0) }

        #expect(await recorder.callCount == 1)
        #expect(await recorder.requests.first?.headers?["Authorization"] == "Profile tok")
        #expect(await authManager.getValidCalls == 1)
    }

    @Test("A 401 forces one refresh and retries with the fresh token")
    func refreshesAndRetriesOn401() async throws {
        let authManager = MockAuthManager(validToken: "stale-tok", refreshedToken: "fresh-tok")
        let interceptor = AuthorizationInterceptor(authManager: authManager)
        let recorder = NextRecorder { callIndex in
            if callIndex == 0 { throw apiError(401) }
            return (Data(), okResponse())
        }

        var request = APIRequest(endpoint: "v2/profile/data/log", method: .POST, requiresAuth: true)
        request.addHeader(name: "X-Sahha-Test", value: "survives")
        let (_, response) = try await interceptor.intercept(request: request) { try await recorder.handle($0) }

        let requests = await recorder.requests
        try #require(requests.count == 2)
        #expect(response.statusCode == 200)
        #expect(requests[0].headers?["Authorization"] == "Profile stale-tok")
        #expect(requests[1].headers?["Authorization"] == "Profile fresh-tok")
        // The retry is rebuilt from the ORIGINAL request — caller headers must survive.
        #expect(requests[0].headers?["X-Sahha-Test"] == "survives")
        #expect(requests[1].headers?["X-Sahha-Test"] == "survives")
        #expect(await authManager.refreshStaleTokens == ["stale-tok"])
        #expect(await authManager.getValidCalls == 1)   // retry does not re-enter getValidProfileToken
    }

    @Test("A persistent 401 retries exactly once, then propagates")
    func retriesOnlyOnce() async throws {
        let authManager = MockAuthManager(validToken: "stale-tok", refreshedToken: "fresh-tok")
        let interceptor = AuthorizationInterceptor(authManager: authManager)
        let recorder = NextRecorder { _ in throw apiError(401) }

        let request = APIRequest(endpoint: "v2/profile/data/log", method: .POST, requiresAuth: true)
        await #expect(throws: APIErrorResponse.self) {
            _ = try await interceptor.intercept(request: request) { try await recorder.handle($0) }
        }

        #expect(await recorder.callCount == 2)   // original + one retry only
        #expect(await authManager.refreshStaleTokens.count == 1)
        #expect(await authManager.getValidCalls == 1)
    }

    @Test(
        "Non-401 API errors propagate without a refresh or a replay",
        arguments: [400, 403, 429, 500]
    )
    func doesNotRefreshOnNon401(statusCode: Int) async throws {
        let authManager = MockAuthManager(validToken: "tok", refreshedToken: "tok-2")
        let interceptor = AuthorizationInterceptor(authManager: authManager)
        let recorder = NextRecorder { _ in throw apiError(statusCode) }

        let request = APIRequest(endpoint: "v2/profile/data/log", method: .POST, requiresAuth: true)
        await #expect(throws: APIErrorResponse.self) {
            _ = try await interceptor.intercept(request: request) { try await recorder.handle($0) }
        }

        // Replaying a POST that the server may have partially processed is never safe — only
        // a 401 (rejected before processing) may be retried.
        #expect(await recorder.callCount == 1)
        #expect(await authManager.refreshStaleTokens.isEmpty)
    }

    @Test("Transport errors propagate without a refresh or a replay")
    func doesNotRefreshOnTransportError() async throws {
        let authManager = MockAuthManager(validToken: "tok", refreshedToken: "tok-2")
        let interceptor = AuthorizationInterceptor(authManager: authManager)
        let recorder = NextRecorder { _ in throw URLError(.timedOut) }

        let request = APIRequest(endpoint: "v1/profile/score", requiresAuth: true)
        await #expect(throws: URLError.self) {
            _ = try await interceptor.intercept(request: request) { try await recorder.handle($0) }
        }

        #expect(await recorder.callCount == 1)
        #expect(await authManager.refreshStaleTokens.isEmpty)
    }

    @Test("A 401 on an unauthenticated request is not intercepted")
    func unauthedRequest401IsNotRetried() async throws {
        let authManager = MockAuthManager(validToken: "tok", refreshedToken: "tok-2")
        let interceptor = AuthorizationInterceptor(authManager: authManager)
        let recorder = NextRecorder { _ in throw apiError(401) }

        let request = APIRequest(endpoint: "v1/oauth/profile/refreshToken", method: .POST, requiresAuth: false)
        await #expect(throws: APIErrorResponse.self) {
            _ = try await interceptor.intercept(request: request) { try await recorder.handle($0) }
        }

        #expect(await recorder.callCount == 1)
        #expect(await authManager.getValidCalls == 0)
        #expect(await authManager.refreshStaleTokens.isEmpty)
    }

    @Test("An unauthenticated manager fails the request before it is sent")
    func getValidThrowingSkipsRequest() async throws {
        let authManager = MockAuthManager(
            validToken: "tok",
            refreshedToken: "tok-2",
            getValidError: SahhaError(message: "Unauthorized. Please call `Sahha.authenticate(...)` first.")
        )
        let interceptor = AuthorizationInterceptor(authManager: authManager)
        let recorder = NextRecorder { _ in (Data(), okResponse()) }

        let request = APIRequest(endpoint: "v1/profile/score", requiresAuth: true)
        await #expect(throws: SahhaError.self) {
            _ = try await interceptor.intercept(request: request) { try await recorder.handle($0) }
        }

        #expect(await recorder.callCount == 0)
    }

    @Test("A 401 whose forced refresh fails surfaces the refresh error, not the original 401")
    func failedRefreshSurfacesSessionError() async throws {
        let authManager = MockAuthManager(
            validToken: "stale-tok",
            refreshedToken: "unused",
            refreshError: SahhaError(message: AuthManager.sessionExpiredMessage)
        )
        let interceptor = AuthorizationInterceptor(authManager: authManager)
        let recorder = NextRecorder { _ in throw apiError(401) }

        let request = APIRequest(endpoint: "v1/profile/score", requiresAuth: true)
        let error = await #expect(throws: SahhaError.self) {
            _ = try await interceptor.intercept(request: request) { try await recorder.handle($0) }
        }

        // The distinct session-expired signal must reach the host, not the generic 401.
        #expect(error?.message == AuthManager.sessionExpiredMessage)
        #expect(await recorder.callCount == 1)   // no retry after a failed refresh
    }
}
