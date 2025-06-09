import Foundation

actor DataLogManager {
    static let shared = DataLogManager()
    
    private let dataLogStore: DataLogStore
    private let batchManager = BatchManager<DataLogRequest>()
    private let batchStore: BatchStore<DataLogRequest>?
    private let batchUploader: BatchUploader<DataLogRequest>?
    private let aggregationManager: AggregationManager?
    private(set) var isReady = false
    
    private init() {
        let paths = DataLogStoragePaths.default()
        self.dataLogStore = DataLogStore(baseDirectory: paths.rawLogs)
        
        do {
            let store = try BatchStore<DataLogRequest>(directory: paths.batches)
            let uploader = BatchUploader<DataLogRequest>(
                retryPolicy: BatchRetryPolicy(
                    intervals: [5, 30, 60],
                    repeatLastInterval: true
                ),
                endpointBuilder: { batch in
                    PostDataLogsEndpoint(request: batch)
                }
            )
            
            self.batchStore = store
            self.batchUploader = uploader
            self.aggregationManager = AggregationManager(
                batchManager: batchManager,
                batchStore: store,
                batchUploader: uploader
            )
            self.isReady = true
        } catch {
            self.batchStore = nil
            self.batchUploader = nil
            self.aggregationManager = nil
            self.isReady = false
        }
    }
    
    func ingest(_ logs: [DataLog]) async -> BatchIngestionResult {
        guard isReady else { return .storageFailed }
        
        let (agg, raw) = logs.partitioned { AggregationConfig.shouldAggregate($0) }
        let aggResult = await aggregationManager?.ingest(agg) ?? .storageFailed
        let rawResult = await handleRawLogs(raw)
        
        return rawResult.merge(with: aggResult)
    }
    
    private func handleRawLogs(_ logs: [DataLog]) async -> BatchIngestionResult {
        do {
            try await dataLogStore.store(logs)
            
            let requests = await logs.concurrentCompactMap { log in
                await log.toRequest()
            }
            
            guard let store = batchStore, let uploader = batchUploader else {
                return .storageFailed
            }
            
            let batches = await batchManager.add(requests)
            
            for batch in batches {
                try await store.save(batch)
                let accepted = await uploader.enqueue(batch)
                if !accepted {
                    return .batchingPaused
                }
            }
            
            return await batchManager.isAtSoftLimit ? .batchingPaused : .success
        } catch {
            return .storageFailed
        }
    }
}
