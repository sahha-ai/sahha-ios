struct APIProvider: ServiceProvider {
    func registerServices(in container: DIContainer) async {
        await container.registerSingleton(APIServiceProtocol.self) { container in
            let baseURL = container.sahhaSettings.environment.baseURL
            return APIService(baseURL: baseURL)
        }
    }
}

