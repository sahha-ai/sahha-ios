enum BiomarkerDI {
    static func registerDependencies(container: DIContainer) async {
        await container.register(BiomarkerServiceProtocol.self) { container in
            BiomarkerService(
                apiClient: try await container.resolve(APIClientProtocol.self)
            )
        }
        await container.register(BiomarkerManagerProtocol.self) { container in
            BiomarkerManager(
                biomarkerService: try await container.resolve(BiomarkerServiceProtocol.self)
            )
        }
    }
}
