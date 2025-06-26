struct DemographicProvider: ServiceProvider {
    func registerServices(in container: DIContainer) async {
        await container.registerSingleton(DemographicServiceProtocol.self) { container in
            let apiService = try await container.resolve(APIServiceProtocol.self)
            return DemographicService(apiService: apiService)
        }
        await container.registerSingleton(DemographicManagerProtocol.self) { container in
            let demographicService = try await container.resolve(DemographicServiceProtocol.self)
            return DemographicManager(demographicService: demographicService)
        }
    }
}
