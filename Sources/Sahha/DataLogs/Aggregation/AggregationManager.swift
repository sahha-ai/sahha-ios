actor AggregationManager {
    private let aggregationStore: AggregationStore
    private let batchManager: BatchManager<DataLogRequest>
    private let batchStore: BatchStore<DataLogRequest>
    private let batchUploader: BatchUploader<DataLogRequest>

    init(batchManager: BatchManager<DataLogRequest>, batchStore: BatchStore<DataLogRequest>, batchUploader: BatchUploader<DataLogRequest>) {
        let paths = DataLogStoragePaths.default()
        self.aggregationStore = AggregationStore(baseDirectory: paths.aggregates)
        self.batchManager = batchManager
        self.batchStore = batchStore
        self.batchUploader = batchUploader
    }

    // TODO: Implement
    func ingest(_ logs: [DataLog]) async -> BatchIngestionResult {
        return .success
    }
    
    func reset() async throws {
        try await aggregationStore.deleteAll()
    }
}
