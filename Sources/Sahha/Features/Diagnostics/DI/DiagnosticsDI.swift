enum DiagnosticsDI {
    static func registerDependencies(container: DIContainer) async {
        await container.register(DiagnosticReportBuilderProtocol.self) { container in
            DiagnosticReportBuilder(
                sensorStore: try await container.resolve(SensorStoreProtocol.self),
                sensorProbe: try await container.resolve(SensorProbeServiceProtocol.self),
                dataLogUploader: try await container.resolve(DataLogUploaderProtocol.self),
                tagUploader: try await container.resolve(TagUploaderProtocol.self),
                storage: try await container.resolve(UserDefaultsStorageProtocol.self),
                logger: try await container.resolve(ErrorLoggerProtocol.self)
            )
        }
        await container.register(DiagnosticUploadServiceProtocol.self) { container in
            DiagnosticUploadService(
                apiClient: try await container.resolve(APIClientProtocol.self),
                reportBuilder: try await container.resolve(DiagnosticReportBuilderProtocol.self),
                logger: try await container.resolve(ErrorLoggerProtocol.self)
            )
        }
        await container.register(DiagnosticConfigLifecycleListener.self) { container in
            DiagnosticConfigLifecycleListener(
                uploadService: try await container.resolve(DiagnosticUploadServiceProtocol.self)
            )
        }
    }
}
