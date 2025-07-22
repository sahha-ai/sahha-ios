protocol TokenStore: Actor {
    func save(_ token: TokenResponse) async throws
    func get() async throws -> TokenResponse?
    func delete() async throws
}
