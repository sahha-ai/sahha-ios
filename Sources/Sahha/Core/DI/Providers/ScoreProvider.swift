struct ScoreProvider: ServiceProvider {
    func registerServices(in container: DIContainer) async {
        await container.registerSingleton(ScoreServiceProtocol.self) { container in
            let apiService = try await container.resolve(APIServiceProtocol.self)
            return ScoreService(apiService: apiService)
        }
    }
}
