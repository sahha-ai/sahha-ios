final class DataLogProcessor: DataLogProcessorProtocol {
    private let batchManager: BatchManager<DataLog>
    
    init(batchManager: BatchManager<DataLog>) {
        self.batchManager = batchManager
    }
    
    // TODO: BatchManager needs to take DataLogRequest?
    // Inject DataLogService and concurrently upload batches, after success batchManager.removeBatch(url)
    
    func process(_ inputs: [DataLog]) async throws {
        await batchManager.add(inputs)
    }
}
