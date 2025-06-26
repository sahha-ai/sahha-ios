struct DeviceInformationProvider: ServiceProvider {
    func registerServices(in container: DIContainer) async {
        await container.registerSingleton(DeviceInformationServiceProtocol.self) { container in
            let apiService = try await container.resolve(APIServiceProtocol.self)
            return DeviceInformationService(apiService: apiService)
        }
        await container.registerSingleton(DeviceInformationManagerProtocol.self) {container in
            let deviceInfoService = try await container.resolve(DeviceInformationServiceProtocol.self)
            let deviceInfoManager = DeviceInformationManager(framework: container.sahhaSettings.framework, deviceInfoService: deviceInfoService)
            let lifecycleObserver = try await container.resolve(LifecycleObserverProtocol.self)
            await lifecycleObserver.addHandler(deviceInfoManager, for: [.appDidBecomeActive])
            return deviceInfoManager
        }
    }
}

