import Foundation

struct DataLogProvider: ServiceProvider {
    func registerServices(in container: DIContainer) async {
        await container.registerSingleton(DataLogServiceProtocol.self) { container in
            let apiService = try await container.resolve(APIServiceProtocol.self)
            return DataLogService(apiService: apiService)
        }
        await container.registerSingleton(DataLogProcessorProtocol.self) { container in
            let logger = try await container.resolve(LoggerProtocol.self)
            
            let batchDirectory = Constants.Directories.baseDirectory.appendingPathComponent("data-logs").appendingPathComponent("batches")
            let fileManager = try BatchFileManager(directory: batchDirectory, logger: logger)
            let batchManager = BatchManager<DataLogRequest>(batchSize: 100, maxPendingBatches: 500, fileManager: fileManager)
            
            let dataLogService = try await container.resolve(DataLogServiceProtocol.self)
            let deviceInformation = try await container.resolve(DeviceInformation.self)
            
            return DataLogProcessor(
                logger: logger,
                batchManager: batchManager,
                dataLogService: dataLogService,
                deviceInformation: deviceInformation
            )
        }
    }
}
