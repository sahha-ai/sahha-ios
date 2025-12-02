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
        await container.register(CircuitBreaker.self) { _ in
            CircuitBreaker()
        }
        await container.register(NetworkMonitor.self) { _ in
            NetworkMonitor()
        }
        await container.register(DeadLetterQueue.self) { _ in
            DeadLetterQueue(
                baseDirectory: StorageDirectories.dataLogs,
                maxStoredBatches: 500
            )
        }
        await container.register(SentLogStore.self) { container in
            SentLogStore(
                storage: try await container.resolve(UserDefaultsStorageProtocol.self)
            )
        }

        await container.register(DataLogUploaderProtocol.self) { container in
            DataLogUploader(
                dataLogService: try await container.resolve(DataLogServiceProtocol.self),
                requestMapper: try await container.resolve(DataLogRequestMapperProtocol.self),
                logger: try await container.resolve(ErrorLoggerProtocol.self),
                circuitBreaker: try await container.resolve(CircuitBreaker.self),
                networkMonitor: try await container.resolve(NetworkMonitor.self),
                persistentQueue: try await container.resolve(DeadLetterQueue.self),
                streamingProcessor: StreamingBatchProcessor(
                    requestMapper: try await container.resolve(DataLogRequestMapperProtocol.self),
                    priorityAssigner: try await container.resolve(UploadPriorityAssignerProtocol.self),
                    config: .default
                ),
                sentLogStore: try await container.resolve(SentLogStore.self)
            )
        }
        await container.register(DataLogPipelineProtocol.self) { container in
            DataLogPipeline(
                uploader: try await container.resolve(DataLogUploaderProtocol.self)
            )
        }
        await container.register(UploadPriorityAssignerProtocol.self) { _ in
            DefaultUploadPriorityAssigner()
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