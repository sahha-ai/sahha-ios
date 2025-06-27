struct APIProvider: ServiceProvider {
    func registerServices(in container: DIContainer) async throws {
        await container.registerSingleton(APIServiceProtocol.self) { container in
            let baseURL = container.sahhaSettings.environment.baseURL
            return try APIService(baseURL: baseURL)
        }
    }
}

