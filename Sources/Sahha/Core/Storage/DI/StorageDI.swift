enum StorageDI {
    static func registerDependencies(container: DIContainer) async {
        await container.register(KeychainStorageProtocol.self) { _ in
            KeychainStorage()
        }
        await container.register(UserDefaultsStorageProtocol.self) { _ in
            UserDefaultsStorage()
        }
    }
}
