protocol AuthManagerProtocol: Sendable {
    func authenticate(appId: String, appSecret: String, externalId: String) async throws
    func authenticate(profileToken: String, refreshToken: String) async throws
    func getValidProfileToken() async throws -> String
    /// Forces a token refresh after the server rejected `staleToken`, returning a fresh
    /// profile token to retry with. Idempotent: if another caller already refreshed past
    /// `staleToken`, the current token is returned without an extra network call.
    func refreshProfileToken(staleToken: String) async throws -> String
    func hasValidProfileToken() async -> Bool
}
