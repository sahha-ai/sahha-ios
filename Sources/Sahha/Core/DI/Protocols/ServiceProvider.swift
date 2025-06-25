protocol ServiceProvider: Sendable {
    func registerServices(in container: DIContainer) async throws
}
