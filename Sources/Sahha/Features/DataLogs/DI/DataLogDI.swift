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
        await container.register(DataLogFileManagerProtocol.self) { _ in
            try DataLogFileManager(
                directory: StorageDirectories.dataLogs,
                logger: try await container.resolve(ErrorLoggerProtocol.self)
            )
        }
        await container.register(DataLogUploaderProtocol.self) { container in
            DataLogUploader(
                fileManager: try await container.resolve(DataLogFileManagerProtocol.self),
                dataLogService: try await container.resolve(DataLogServiceProtocol.self),
                requestMapper: try await container.resolve(DataLogRequestMapperProtocol.self),  
                logger: try await container.resolve(ErrorLoggerProtocol.self),
                priorityAssigner: try await container.resolve(UploadPriorityAssignerProtocol.self)  
            )
        }
        await container.register(DataLogPipelineProtocol.self) { container in
            DataLogPipeline(
                fileManager: try await container.resolve(DataLogFileManagerProtocol.self),
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
