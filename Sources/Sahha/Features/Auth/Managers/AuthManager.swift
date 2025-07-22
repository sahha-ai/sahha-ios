protocol AuthManager: Sendable {
    func authorize(appId: String, appSecret: String, externalId: String) async throws
    func authorize(profileToken: String, refreshToken: String) async throws
}
