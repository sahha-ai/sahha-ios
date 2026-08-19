enum DataLogDI {
    static func registerDependencies(container: DIContainer) async {
        // Use standard API client - background session delegates handle actual uploads
        await container.register(DataLogServiceProtocol.self) { container in
            DataLogService(
                apiClient: try await container.resolve(APIClientProtocol.self)
            )
        }
        await container.register(DataLogRequestMapperProtocol.self) { container in
            DataLogRequestMapper(
                deviceId: try await container.resolve(DeviceIdProviderProtocol.self).deviceId(),
                logger: try await container.resolve(ErrorLoggerProtocol.self)
            )
        }
        await container.register(UploadPriorityAssignerProtocol.self) { _ in
            DefaultUploadPriorityAssigner()
        }

        // Unified upload infrastructure for DataLogs
        let dataLogCircuitBreaker = CircuitBreaker()
        let dataLogNetworkMonitor = NetworkMonitor()

        await container.register(DataLogUploaderProtocol.self) { container in
            let service = try await container.resolve(DataLogServiceProtocol.self)
            let mapper = try await container.resolve(DataLogRequestMapperProtocol.self)
            let priorityAssigner = try await container.resolve(UploadPriorityAssignerProtocol.self)

            return UnifiedUploader<DataLog, DataLogRequest>(
                uploadService: { requests in
                    try await service.postDataLogs(requests)
                },
                logger: try await container.resolve(ErrorLoggerProtocol.self),
                circuitBreaker: dataLogCircuitBreaker,
                networkMonitor: dataLogNetworkMonitor,
                persistentQueue: UnifiedDeadLetterQueue<DataLogRequest>(
                    baseDirectory: StorageDirectories.dataLogs,
                    maxStoredBatches: 500,
                    logLabel: "DataLog Persistent Queue"
                ),
                streamingProcessor: StreamingChunkProcessor<DataLog, DataLogRequest>(
                    mapItem: { log in mapper.map(log) },
                    assignPriority: { log in priorityAssigner.assignPriority(to: log) },
                    config: .default
                ),
                sentStore: SentItemStore(
                    storage: try await container.resolve(UserDefaultsStorageProtocol.self),
                    storageKey: StorageKeys.UserDefaults.sentLogIds.rawValue,
                    logLabel: "SentLogStore"
                ),
                logLabel: "DataLogUploader"
            )
        }

        await container.register(DataLogPipelineProtocol.self) { container in
            DataLogPipeline(
                uploader: try await container.resolve(DataLogUploaderProtocol.self)
            )
        }

        // Lifecycle listener that retries pending uploads on app resume/unlock
        await container.register(DataLogRetryLifecycleListener.self) { container in
            DataLogRetryLifecycleListener(
                uploader: try await container.resolve(DataLogUploaderProtocol.self)
            )
        }
    }
}

//// Adjust what gets prioritized here
final class DefaultUploadPriorityAssigner: UploadPriorityAssignerProtocol {
    func assignPriority(to log: DataLog) -> UploadPriority {
        // Critical: Steps data only
        if log.dataType == "steps" {
            return .critical
        }

        // High: All HealthKit data types
        switch log.logType {
        case .sleep, .activity, .heart, .blood, .oxygen, .energy, .temperature, .body:
            return .high

        // Normal: Device logs, demographic, and everything else
        default:
            return .normal
        }
    }
}
