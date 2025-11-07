import Foundation

actor DataLogUploader: DataLogUploaderProtocol, Disposable {
    private let dataLogService: DataLogServiceProtocol
    private let requestMapper: DataLogRequestMapperProtocol
    private let logger: ErrorLoggerProtocol
    private let circuitBreaker: CircuitBreaker
    private let networkMonitor: NetworkMonitor
    private let persistentQueue: DeadLetterQueue
    private let streamingProcessor: StreamingBatchProcessor
    private let uploadSemaphore: AsyncSemaphore
    private let maxRetries: Int
    private let chunkQueue = ChunkQueue()
    private var uploadTask: Task<Void, Never>? = nil
    private var hasLoadedPersistedData = false

    init(
        dataLogService: DataLogServiceProtocol,
        requestMapper: DataLogRequestMapperProtocol,
        logger: ErrorLoggerProtocol,
        circuitBreaker: CircuitBreaker,
        networkMonitor: NetworkMonitor,
        persistentQueue: DeadLetterQueue,
        streamingProcessor: StreamingBatchProcessor,
        config: UploadConfig = .default
    ) {
        self.dataLogService = dataLogService
        self.requestMapper = requestMapper
        self.logger = logger
        self.circuitBreaker = circuitBreaker
        self.networkMonitor = networkMonitor
        self.persistentQueue = persistentQueue
        self.streamingProcessor = streamingProcessor
        self.uploadSemaphore = AsyncSemaphore(value: max(config.maxConcurrentUploads, 1))
        self.maxRetries = max(config.maxRetries, 1)
        
        // Inject network monitor into circuit breaker with connectivity callbacks
        // Circuit breaker will automatically transition to half-open when network reconnects
        Task { [weak circuitBreaker, weak networkMonitor] in
            guard let circuitBreaker, let networkMonitor else { return }
            await circuitBreaker.setNetworkMonitor(networkMonitor)
        }
    }

    func enqueue(_ chunk: DataLogChunk) async {
        await chunkQueue.enqueue(chunk)
        await startUploadLoopIfNeeded()
    }

    func enqueueLogs(_ logs: [DataLog]) async {
        await streamingProcessor.streamChunks(from: logs) { [weak self] chunk in
            guard let self else { return }
            await self.enqueue(chunk)
        }
    }

    private func startUploadLoopIfNeeded() async {
        guard uploadTask == nil else { return }
        
        // Load persisted data on first startup
        if !hasLoadedPersistedData {
            await loadPersistedData()
            hasLoadedPersistedData = true
        }
        
        uploadTask = Task { [weak self] in
            guard let self else { return }
            await self.networkMonitor.startMonitoring()
            await self.runUploadLoop()
        }
    }
    
    /// Load all persisted batches from disk
    /// Includes both offline storage and previously failed batches
    private func loadPersistedData() async {
        let persistedBatches = await persistentQueue.loadAllBatches()
        
        for batch in persistedBatches {
            // Re-enqueue all persisted data with original priority and track their IDs
            await chunkQueue.enqueue(batch.chunk, persistedId: batch.id)
        }
        
        let failedCount = persistedBatches.filter { $0.hasFailed }.count
        print("[DataLogUploader] Loaded \(persistedBatches.count) persisted batches (\(failedCount) previously failed)")
    }
    

    private func runUploadLoop() async {
        while !Task.isCancelled {
            guard let chunk = await chunkQueue.dequeue() else {
                await networkMonitor.stopMonitoring()
                break
            }

            await uploadSemaphore.wait()
            Task { [weak self] in
                guard let self else { return }
                await self.uploadChunk(chunk)
                await self.uploadSemaphore.signal()
            }
        }
        uploadTask = nil
    }

    private func uploadChunk(_ queuedChunk: QueuedChunk) async {
        let chunk = queuedChunk.chunk
        var persistedIds = Set<String>()
        if let id = queuedChunk.persistedId {
            persistedIds.insert(id)
        }
        var attempt = 0
        var wasOffline = false

        while attempt < maxRetries && !Task.isCancelled {
            do {
                try Task.checkCancellation()

                // Check if device is offline
                let isOffline = !(await networkMonitor.shouldAttemptUpload())
                
                if isOffline {
                    // Persist chunk to disk if going offline
                    if !wasOffline {
                        print("[DataLogUploader] Device offline, persisting chunk with \(chunk.requests.count) logs")
                        if let id = await persistentQueue.persistBatch(
                            chunk,
                            attemptCount: attempt,
                            lastError: nil  // No error - just offline
                        ) {
                            persistedIds.insert(id)
                        }
                        wasOffline = true
                    }
                    
                    // Wait for connectivity without consuming retry attempts
                    try await networkMonitor.waitForConnectivity(timeout: 60)
                    
                    // If we get here, network is back - continue to upload
                    print("[DataLogUploader] Network restored, resuming upload for chunk")
                    wasOffline = false
                    continue
                }

                guard await circuitBreaker.shouldAllowRequest() else {
                    try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    continue
                }

                try await dataLogService.postDataLogs(chunk.requests)
                await circuitBreaker.recordSuccess()
                print("[DataLogUploader] Successfully uploaded chunk with \(chunk.requests.count) logs (priority: \(chunk.priority))")
                // Remove any persisted copies now that upload succeeded
                for id in persistedIds {
                    await persistentQueue.removeBatch(withId: id)
                }
                return
            } catch {
                attempt += 1
                await circuitBreaker.recordFailure()
                logger.postError(error)

                // If offline, persist and wait instead of retrying
                if !(await networkMonitor.shouldAttemptUpload()) {
                    print("[DataLogUploader] Upload failed due to offline state, persisting chunk")
                    _ = await persistentQueue.persistBatch(
                        chunk,
                        attemptCount: attempt,
                        lastError: nil  // Offline, not a real failure
                    )
                    return  // Exit retry loop, will be retried on network restoration
                }

                let backoffExponent = Double(min(max(attempt - 1, 0), 4))
                let waitMinutes = pow(2.0, backoffExponent)
                let waitTime = min(TimeInterval.minutes(waitMinutes), TimeInterval.minutes(16))
                try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }

        // Max retries exceeded - persist with failure metadata
        let errorMessage = "Max retry attempts exceeded for chunk with priority \(chunk.priority)"
        let error = NSError(
            domain: "DataLogUploader",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: errorMessage]
        )
        logger.postError(error)
        
        // Store as failed batch (will be retried on next app launch or network restoration)
        _ = await persistentQueue.persistBatch(
            chunk,
            attemptCount: attempt,
            lastError: errorMessage  // Mark as failed with error
        )
    }

    func dispose() async {
        uploadTask?.cancel()
        uploadTask = nil
        await chunkQueue.clear()
        await networkMonitor.stopMonitoring()
    }
}

private struct QueuedChunk {
    let chunk: DataLogChunk
    let persistedId: String?
}

private actor ChunkQueue {
    private var storage: [UploadPriority: [QueuedChunk]] = [:]

    func enqueue(_ chunk: DataLogChunk, persistedId: String? = nil) {
        let item = QueuedChunk(chunk: chunk, persistedId: persistedId)
        storage[chunk.priority, default: []].append(item)
    }

    func dequeue() -> QueuedChunk? {
        for priority in [UploadPriority.critical, .high, .normal, .low] {
            if var queue = storage[priority], !queue.isEmpty {
                let item = queue.removeFirst()
                storage[priority] = queue
                return item
            }
        }
        return nil
    }

    func clear() {
        storage.removeAll()
    }
}

