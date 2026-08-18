enum SensorDI {
    static func registerDependencies(container: DIContainer) async {
        await container.register(SensorStoreProtocol.self) { container in
            SensorStore(
                storage: try await container.resolve(UserDefaultsStorageProtocol.self)
            )
        }
        await container.register(SensorProbeServiceProtocol.self) { container in
            SensorProbeService(
                sensorStore: try await container.resolve(SensorStoreProtocol.self),
                sampleQueryService: try await container.resolve(HealthKitSampleQueryServiceProtocol.self),
                logger: try await container.resolve(ErrorLoggerProtocol.self)
            )
        }
        await container.register(SensorProbeLifecycleListener.self) { container in
            SensorProbeLifecycleListener(
                probeService: try await container.resolve(SensorProbeServiceProtocol.self)
            )
        }
    }
}
