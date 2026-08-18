protocol AuthManagerProtocol: Sendable {
    func authenticate(appId: String, appSecret: String, externalId: String) async throws
    func authenticate(profileToken: String, refreshToken: String) async throws
    func getValidProfileToken() async throws -> String
    /// Forces a token refresh after the server rejected `staleToken`, returning a fresh
    /// profile token to retry with. Idempotent: if another caller already refreshed past
    /// `staleToken`, the current token is returned without an extra network call.
    func refreshProfileToken(staleToken: String) async throws -> String
    func hasValidProfileToken() async -> Bool
    /// Classifies the persisted session for the authenticated bring-up gate (PRD #76
    /// D10): start now, defer and retry, or never retry.
    func launchVerdict() async -> LaunchAuthVerdict
    /// Installs the handler invoked after every successful token refresh (the D10
    /// deferred bring-up piggyback). The handler runs synchronously inside the refresh
    /// flight: it must dispatch its own task and never re-enter the auth manager
    /// directly, or it would self-join the still-open flight.
    func setOnRefreshSuccess(_ handler: (@Sendable () -> Void)?) async
}

extension AuthManagerProtocol {
    /// Doubles that only script token validity keep their behavior: a valid token
    /// starts bring-up now, anything else reads as signed out.
    func launchVerdict() async -> LaunchAuthVerdict {
        await hasValidProfileToken() ? .valid : .unauthenticated
    }

    func setOnRefreshSuccess(_ handler: (@Sendable () -> Void)?) async {}
}
