enum SensorDI {
    static func registerDependencies(container: DIContainer) async {
        await container.register(SensorStoreProtocol.self) { container in
            SensorStore(
                storage: try await container.resolve(UserDefaultsStorageProtocol.self)
            )
        }
    }
}
