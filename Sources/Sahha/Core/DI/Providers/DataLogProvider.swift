import Foundation

struct DataLogProvider: ServiceProvider {
    public func registerServices(in container: DIContainer) async {
        await container.registerSingleton((any DataLogProcessorProtocol).self) { container in
            let batchDirectory = Constants.Directories.baseDirectory.appendingPathComponent("batches")
            let fileManager = BatchFileManager(directory: batchDirectory)
            let batchManager = BatchManager<DataLog>(batchSize: 100, maxPendingBatches: 50, fileManager: fileManager)
            return DataLogProcessor(batchManager: batchManager)
        }
    }
}
