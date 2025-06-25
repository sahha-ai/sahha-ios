protocol AuthenticationServiceProtocol: Sendable {
    func registerProfile(appId: String, appSecret: String, externalId: String) async throws -> TokenResponse
    func refreshToken(refreshToken: String) async throws -> TokenResponse
}
