enum ScoreDI {
    static func registerDependencies(container: DIContainer) async {
        await container.register(ScoreServiceProtocol.self) { container in
            ScoreService(
                apiClient: try await container.resolve(APIClientProtocol.self)
            )
        }
        await container.register(ScoreManagerProtocol.self) { container in
            ScoreManager(
                scoreService: try await container.resolve(ScoreServiceProtocol.self)
            )
        }
    }
}
