enum DemographicDI {
    static func registerDependencies(container: DIContainer) async {
        await container.register(DemographicCacheProtocol.self) { container in
            DemographicCache(
                storage: try await container.resolve(KeychainStorageProtocol.self),
                logger: try await container.resolve(ErrorLoggerProtocol.self)
            )
        }
        await container.register(DemographicServiceProtocol.self) { container in
            DemographicService(
                apiClient: try await container.resolve(APIClientProtocol.self)
            )
        }
        await container.register(DemographicManagerProtocol.self) { container in
            DemographicManager(
                demographicService: try await container.resolve(DemographicServiceProtocol.self),
                sensorStore: try await container.resolve(SensorStoreProtocol.self),
                cache: try await container.resolve(DemographicCacheProtocol.self),
                logger: try await container.resolve(ErrorLoggerProtocol.self)
            )
        }
    }
}
