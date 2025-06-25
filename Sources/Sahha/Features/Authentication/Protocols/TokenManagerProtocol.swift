protocol TokenManagerProtocol: Actor {
    func saveToken(_ token: TokenResponse) async throws
    func getProfileToken() async -> String?
    func getRefreshToken() async -> String?
    func removeTokens() async throws
    func ensureValidProfileToken() async throws -> String?
}
