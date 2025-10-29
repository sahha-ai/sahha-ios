enum DataLogDI {
    static func registerDependencies(container: DIContainer) async {
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
            DeadLetterQueue(baseDirectory: StorageDirectories.dataLogs)
        }
        await container.register(OfflineQueuePersistence.self) { _ in
            OfflineQueuePersistence(baseDirectory: StorageDirectories.dataLogs)
        }

        await container.register(DataLogUploaderProtocol.self) { container in
            DataLogUploader(
                dataLogService: try await container.resolve(DataLogServiceProtocol.self),
                requestMapper: try await container.resolve(DataLogRequestMapperProtocol.self),
                logger: try await container.resolve(ErrorLoggerProtocol.self),
                circuitBreaker: try await container.resolve(CircuitBreaker.self),
                networkMonitor: try await container.resolve(NetworkMonitor.self),
                deadLetterQueue: try await container.resolve(DeadLetterQueue.self),
                offlineQueue: try await container.resolve(OfflineQueuePersistence.self),
                streamingProcessor: StreamingBatchProcessor(
                    requestMapper: try await container.resolve(DataLogRequestMapperProtocol.self),
                    priorityAssigner: try await container.resolve(UploadPriorityAssignerProtocol.self)
                )
            )
        }
        await container.register(DataLogPipelineProtocol.self) { container in
            DataLogPipeline(
                requestMapper: try await container.resolve(DataLogRequestMapperProtocol.self),
                uploader: try await container.resolve(DataLogUploaderProtocol.self),
                priorityAssigner: try await container.resolve(UploadPriorityAssignerProtocol.self) 
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
        switch log.logType {
        case .device: return .high  
        case .demographic: return .critical  
        default: return .normal  
        }
    }
}