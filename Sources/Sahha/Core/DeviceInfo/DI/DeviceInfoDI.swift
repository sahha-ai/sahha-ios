enum DeviceInfoDI {
    static func registerDependencies(container: DIContainer, settings: SahhaSettings) async {
        await container.register(DeviceIdProviderProtocol.self) { container in
            DeviceIdProvider(
                storage: try await container.resolve(UserDefaultsStorageProtocol.self)
            )
        }
        await container.register(DeviceInfoBuilderProtocol.self) { container in
            DeviceInfoBuilder(
                sdkId: settings.framework.rawValue,
                deviceIdProvider: try await container.resolve(DeviceIdProviderProtocol.self)
            )
        }
    }
}
