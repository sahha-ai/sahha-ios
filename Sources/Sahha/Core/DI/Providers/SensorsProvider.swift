struct SensorsProvider: ServiceProvider {
    func registerServices(in container: DIContainer) async {
        await container.registerSingleton(SensorsManagerProtocol.self) { container in
            let hkManager = try await container.resolve(HKManagerProtocol.self)
            return SensorsManager(hkManager: hkManager)
        }
    }
}
