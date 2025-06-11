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
        SahhaLogger.info("AppSupport base directory for Sahha: \(paths.baseDirectory)")
        self.dataLogStore = DataLogStore(baseDirectory: paths.rawLogs)
        
        do {
            let store = try BatchStore<DataLogRequest>(baseDirectory: paths.batches)
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
        guard isReady else {
            SahhaLogger.warning("Ingest called but DataLogManager is not ready.")
            return .storageFailed
        }
        
        SahhaLogger.info("Ingesting \(logs.count) logs.")
        let (agg, raw) = logs.partitioned { AggregationConfig.shouldAggregate($0) }
        SahhaLogger.info("Partitioned into \(agg.count) aggregate logs and \(raw.count) raw logs.")
        
        let aggResult = await aggregationManager?.ingest(agg) ?? .storageFailed
        let rawResult = await handleRawLogs(raw)
        
        return rawResult.merge(with: aggResult)
    }
    
    func reset() async {
        SahhaLogger.warning("DataLogManager reset initiated.")

        await batchUploader?.cancelAll()
        await batchManager.reset()

        do {
            try await dataLogStore.deleteAll()
            try await aggregationManager?.reset()
            try await batchStore?.deleteAll()
        } catch {
            SahhaLogger.error("Failed to clear persistent stores during reset: \(error.localizedDescription)")
        }

        SahhaLogger.info("Reset complete. All in-memory and persistent state cleared.")
    }
    
    private func handleRawLogs(_ logs: [DataLog]) async -> BatchIngestionResult {
        guard !logs.isEmpty else {
            SahhaLogger.info("No raw logs to process.")
            return .success
        }
        
        do {
            SahhaLogger.info("Storing \(logs.count) raw logs.")
            try await dataLogStore.store(logs)
            
            let requests = await logs.concurrentCompactMap { log in
                await log.toRequest()
            }
            SahhaLogger.info("Converted to \(requests.count) DataLogRequest items.")
            
            guard let store = batchStore, let uploader = batchUploader else {
                SahhaLogger.error("Batch store or uploader is not initialized.")
                return .storageFailed
            }
            
            let batches = await batchManager.add(requests)
            SahhaLogger.info("Generated \(batches.count) new batches.")
            
            for batch in batches {
                try await store.save(batch)
                SahhaLogger.info("Saved batch with \(batch.count) requests.")
                let accepted = await uploader.enqueue(batch)
                if !accepted {
                    SahhaLogger.warning("Uploader queue full — batching paused.")
                    return .batchingPaused
                }
                SahhaLogger.info("Batch enqueued for upload.")
            }
            
            let atLimit = await batchManager.isAtSoftLimit
            SahhaLogger.info("Batching complete. Soft limit reached: \(atLimit)")
            return atLimit ? .batchingPaused : .success
        } catch {
            SahhaLogger.error("Failed during raw log handling: \(error.localizedDescription)")
            return .storageFailed
        }
    }
}
