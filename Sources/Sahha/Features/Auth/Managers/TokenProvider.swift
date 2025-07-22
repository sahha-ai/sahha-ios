protocol TokenProvider: Sendable, Disposable {
    func saveToken(_ token: TokenResponse) async throws
    func validProfileToken() async throws -> String
}
