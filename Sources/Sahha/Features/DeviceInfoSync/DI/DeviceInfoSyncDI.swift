enum DeviceInfoSyncDI {
    static func registerDependencies(container: DIContainer) async {
        await container.register(DeviceInfoSyncCacheProtocol.self) { container in
            DeviceInfoSyncCache(
                storage: try await container.resolve(UserDefaultsStorageProtocol.self),
                logger: try await container.resolve(ErrorLoggerProtocol.self)
            )
        }
        await container.register(DeviceInfoSyncServiceProtocol.self) { container in
            DeviceInfoSyncService(
                apiClient: try await container.resolve(APIClientProtocol.self)
            )
        }
        await container.register(DeviceInfoSyncManagerProtocol.self) { container in
            DeviceInfoSyncManager(
                deviceInfoBuilder: try await container.resolve(DeviceInfoBuilderProtocol.self),
                deviceInfoCache: try await container.resolve(DeviceInfoSyncCacheProtocol.self),
                deviceInfoService: try await container.resolve(DeviceInfoSyncServiceProtocol.self),
                logger: try await container.resolve(ErrorLoggerProtocol.self)
            )
        }
        await container.register(DeviceInfoSyncLifecycleListener.self) { container in
            DeviceInfoSyncLifecycleListener(
                deviceInfoSyncManager: try await container.resolve(DeviceInfoSyncManagerProtocol.self)
            )
        }
    }
}
