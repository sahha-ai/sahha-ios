struct BiomarkerProvider: ServiceProvider {
    func registerServices(in container: DIContainer) async {
        await container.registerSingleton(BiomarkerServiceProtocol.self) { container in
            let apiService = try await container.resolve(APIServiceProtocol.self)
            return BiomarkerService(apiService: apiService)
        }
    }
}
