struct AppEventProvider: ServiceProvider {
    func registerServices(in container: DIContainer) async {
        await container.registerSingleton(AppEventManagerProtocol.self) { container in
            let lifecycleObserver = try await container.resolve(LifecycleObserverProtocol.self)
            let sensorsManager = try await container.resolve(SensorsManagerProtocol.self)
            let deviceInfoManager = try await container.resolve(DeviceInformationManagerProtocol.self)
            let dataLogProcessor = try await container.resolve((any DataLogProcessorProtocol).self)
            return AppEventManager(
                lifecycleObserver: lifecycleObserver,
                sensorsManager: sensorsManager,
                dataLogProcessor: dataLogProcessor,
                deviceInfoManager: deviceInfoManager
            )
        }
    }
}
