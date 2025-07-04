struct DeviceProvider: ServiceProvider {
    func registerServices(in container: DIContainer) async {
        await container.registerSingleton(DeviceServiceProtocol.self) { container in
            let apiService = try await container.resolve(APIServiceProtocol.self)
            return DeviceService(apiService: apiService)
        }
        await container.registerSingleton(DeviceManagerProtocol.self) {container in
            let logger = try await container.resolve(LoggerProtocol.self)
            let deviceInformation = try await container.resolve(DeviceInformation.self)
            let deviceService = try await container.resolve(DeviceServiceProtocol.self)
            let lifecycleObserver = try await container.resolve(LifecycleObserverProtocol.self)
            let sensorsManager = try await container.resolve(SensorsManagerProtocol.self)
            let dataLogProcessor = try await container.resolve(DataLogProcessorProtocol.self)
            
            return DeviceManager(
                logger: logger,
                deviceInformation: deviceInformation,
                deviceService: deviceService,
                lifecycleObserver: lifecycleObserver,
                sensorsManager: sensorsManager,
                dataLogProcessor: dataLogProcessor
            )
        }
    }
}

