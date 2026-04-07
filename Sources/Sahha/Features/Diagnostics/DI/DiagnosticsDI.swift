enum DiagnosticsDI {
    static func registerDependencies(container: DIContainer) async {
        await container.register(DiagnosticReportBuilderProtocol.self) { container in
            DiagnosticReportBuilder(
                sensorStore: try await container.resolve(SensorStoreProtocol.self),
                healthCheckListener: try await container.resolve(SensorHealthCheckLifecycleListener.self),
                dataLogUploader: try await container.resolve(DataLogUploaderProtocol.self),
                tagUploader: try await container.resolve(TagUploaderProtocol.self),
                circuitBreaker: try? await container.resolve(CircuitBreaker.self),
                networkMonitor: try await container.resolve(NetworkMonitor.self),
                deviceInfoBuilder: try await container.resolve(DeviceInfoBuilderProtocol.self),
                storage: try await container.resolve(UserDefaultsStorageProtocol.self)
            )
        }
    }
}
