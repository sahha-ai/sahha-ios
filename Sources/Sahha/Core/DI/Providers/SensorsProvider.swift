struct SensorsProvider: ServiceProvider {
    func registerServices(in container: DIContainer) async {
        await container.registerSingleton(SensorsManagerProtocol.self) { container in
            let logger = try await container.resolve(LoggerProtocol.self)
            let hkManager = try await container.resolve(HealthKitManagerProtocol.self)
            return SensorsManager(logger: logger, hkManager: hkManager)
        }
    }
}
