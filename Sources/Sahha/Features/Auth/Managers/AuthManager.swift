import Foundation

final class AuthManager: AuthManagerProtocol, Disposable {
    private let authService: AuthServiceProtocol
    private let tokenStore: TokenStoreProtocol
    private let logger: ErrorLoggerProtocol
    private let expiryOffset: TimeInterval

    private let refreshTaskActor = SingleThrowingTaskActor<TokenResponse>()
    private let refreshPacer = RefreshPacer()

    private static let unauthenticatedMessage = "Unauthorized. Please call `Sahha.authenticate(...)` first."
    static let sessionExpiredMessage = "Session expired. Please authenticate again."

    /// A successful refresh within this window suppresses further network refreshes for the
    /// same profile token, so a server that 401s freshly minted tokens for non-credential
    /// reasons cannot force one refresh-token rotation per failing request.
    private static let minRefreshInterval: TimeInterval = 10

    init(
        authService: AuthServiceProtocol,
        tokenStore: TokenStoreProtocol,
        logger: ErrorLoggerProtocol,
        expiryOffset: TimeInterval = .minutes(30)
    ) {
        self.authService = authService
        self.tokenStore = tokenStore
        self.logger = logger
        self.expiryOffset = expiryOffset
    }

    func authenticate(appId: String, appSecret: String, externalId: String) async throws {
        guard !appId.isEmpty else {
            throw SahhaError(message: "App id cannot be empty.")
        }
        guard !appSecret.isEmpty else {
            throw SahhaError(message: "App secret cannot be empty.")
        }
        guard !externalId.isEmpty else {
            throw SahhaError(message: "External id cannot be empty.")
        }

        do {
            let response = try await authService.authenticate(appId: appId, appSecret: appSecret, externalId: externalId)
            try await tokenStore.saveToken(response)
        } catch {
            logger.postError(error)
            throw error
        }
    }

    func authenticate(profileToken: String, refreshToken: String) async throws {
        guard !profileToken.isEmpty else {
            throw SahhaError(message: "Profile token cannot be empty.")
        }
        guard !refreshToken.isEmpty else {
            throw SahhaError(message: "Refresh token cannot be empty.")
        }
        do {
            let response = TokenResponse(profileToken: profileToken, refreshToken: refreshToken)
            try await tokenStore.saveToken(response)
        } catch {
            logger.postError(error)
            throw error
        }
    }

    func getValidProfileToken() async throws -> String {
        guard let token = await tokenStore.token() else {
            throw SahhaError(message: Self.unauthenticatedMessage)
        }
        guard JWT.isExpired(token.profileToken, offset: expiryOffset) else { return token.profileToken }
        return try await refresh(replacing: token.profileToken)
    }

    func refreshProfileToken(staleToken: String) async throws -> String {
        try await refresh(replacing: staleToken)
    }

    func hasValidProfileToken() async -> Bool {
        do {
            _ = try await getValidProfileToken()
            return true
        } catch {
            return false
        }
    }

    /// Refreshes the stored token at most once across concurrent callers.
    ///
    /// `staleToken` is the profile token the caller found unusable — either locally expired
    /// (proactive path) or rejected by the server with a 401 (reactive path).
    private func refresh(replacing staleToken: String) async throws -> String {
        let first = try await runRefreshFlight(replacing: staleToken)
        guard first.profileToken == staleToken else { return first.profileToken }
        // This caller joined a flight keyed to a DIFFERENT stale token, and that flight took
        // the reuse-stored-token branch — handing back the very token this caller found
        // unusable. Run one more flight keyed to ours. The second result is returned
        // unconditionally, so this cannot loop.
        let second = try await runRefreshFlight(replacing: staleToken)
        return second.profileToken
    }

    /// One single-flight pass: concurrent callers share one network refresh, and the rotated
    /// pair is persisted *inside* the flight so it is cached before any waiter resumes.
    private func runRefreshFlight(replacing staleToken: String) async throws -> TokenResponse {
        try await refreshTaskActor.run {
            guard let current = await self.tokenStore.token() else {
                throw SahhaError(message: Self.unauthenticatedMessage)
            }
            // Another flight already rotated past the caller's token — reuse the stored one
            // rather than burning the (possibly already-rotated) refresh token a second time.
            if current.profileToken != staleToken, !JWT.isExpired(current.profileToken) {
                return current
            }
            // The refresh token is itself a JWT carrying the exact `exp` claim the server
            // checks. Catching an expired or unparseable one locally makes the dead-session
            // verdict independent of the server's status-code choice (it returns 400 for this
            // today) and skips the doomed round trip entirely.
            if JWT.isExpired(current.refreshToken) {
                throw await self.expireSession(cause: nil)
            }
            // A refresh succeeded moments ago, so the stored token *should* be good; a server
            // rejecting it anyway is doing so for a non-credential reason. Hand the token back
            // and let that failure propagate instead of rotating once per failing request.
            if current.profileToken == staleToken,
                await self.refreshPacer.refreshedWithin(Self.minRefreshInterval) {
                return current
            }
            do {
                let response = try await self.authService.refreshToken(refreshToken: current.refreshToken)
                // A flight cancelled by dispose() (deauthentication mid-refresh) must not
                // resurrect the session by writing tokens back after the store was wiped.
                try Task.checkCancellation()
                try await self.tokenStore.saveToken(response)
                await self.refreshPacer.recordSuccess()
                return response
            } catch {
                if Self.isSessionTerminal(error, refreshToken: current.refreshToken) {
                    throw await self.expireSession(cause: error)
                }
                // Transient failure (offline, rate limit, server error): keep the tokens so a
                // later attempt can recover without forcing a full re-authentication.
                throw error
            }
        }
    }

    /// Clears the dead session and returns the distinct error to throw. Reports the cause
    /// first — once the store is cleared, no authenticated request can carry it.
    private func expireSession(cause: Error?) async -> SahhaError {
        let sessionError = SahhaError(message: Self.sessionExpiredMessage, error: cause)
        logger.postError(cause ?? sessionError)
        await tokenStore.clearToken()
        return sessionError
    }

    /// Whether a refresh failure means the session is unrecoverable.
    ///
    /// 401/403 are authoritative. Other 4xx are ambiguous — today's server returns 400 for an
    /// expired refresh token, but 400 is also what a malformed request produces, and clearing
    /// the session on a client bug would sign out the entire fleet (re-auth usually needs the
    /// host's server-held app secret) — so they count only when the stored refresh token
    /// independently corroborates the verdict via its own `exp`. Timeouts, rate limits, server
    /// errors, and network failures are always transient.
    private static func isSessionTerminal(_ error: Error, refreshToken: String) -> Bool {
        guard let statusCode = (error as? APIErrorResponse)?.statusCode else { return false }
        switch statusCode {
        case 401, 403:
            return true
        case 404, 408, 429:
            return false
        case 400...499:
            return JWT.isExpired(refreshToken)
        default:
            return false
        }
    }

    func dispose() async {
        await refreshTaskActor.cancel()
    }
}

/// Serializes "when did the last refresh succeed" across concurrent flights.
private actor RefreshPacer {
    private var lastSuccess: Date?

    func recordSuccess() {
        lastSuccess = Date()
    }

    func refreshedWithin(_ interval: TimeInterval) -> Bool {
        guard let lastSuccess else { return false }
        return Date().timeIntervalSince(lastSuccess) < interval
    }
}
