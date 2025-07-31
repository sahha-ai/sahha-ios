protocol AuthManagerProtocol: Sendable {
    func authenticate(appId: String, appSecret: String, externalId: String) async throws
    func authenticate(profileToken: String, refreshToken: String) async throws
    func getValidProfileToken() async throws -> String
    func hasValidProfileToken() async -> Bool
}
