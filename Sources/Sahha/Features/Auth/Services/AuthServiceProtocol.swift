protocol AuthServiceProtocol: Sendable {
    func authenticate(appId: String, appSecret: String, externalId: String) async throws -> TokenResponse
    func refreshToken(refreshToken: String) async throws -> TokenResponse
}
