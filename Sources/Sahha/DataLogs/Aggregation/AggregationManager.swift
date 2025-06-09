actor AggregationManager {
    private let batchManager: BatchManager<DataLogRequest>
    private let batchStore: BatchStore<DataLogRequest>
    private let batchUploader: BatchUploader<DataLogRequest>

    init(batchManager: BatchManager<DataLogRequest>, batchStore: BatchStore<DataLogRequest>, batchUploader: BatchUploader<DataLogRequest>) {
        self.batchManager = batchManager
        self.batchStore = batchStore
        self.batchUploader = batchUploader
    }

    // TODO: Implement
    func ingest(_ logs: [DataLog]) async -> BatchIngestionResult {
        return .success
    }
}
