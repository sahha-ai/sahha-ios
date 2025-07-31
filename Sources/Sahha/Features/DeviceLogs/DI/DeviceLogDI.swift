enum DeviceLogDI {
    static func registerDependencies(container: DIContainer) async {
        await container.register(DeviceLogLifecycleListener.self) { container in
            DeviceLogLifecycleListener(
                sensorStore: try await container.resolve(SensorStoreProtocol.self),
                deviceInfoBuilder: try await container.resolve(DeviceInfoBuilderProtocol.self),
                dataLogPipeline: try await container.resolve(DataLogPipelineProtocol.self)
            )
        }
    }
}
