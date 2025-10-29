import Foundation

actor DataLogUploader: DataLogUploaderProtocol, Disposable {
    private let dataLogService: DataLogServiceProtocol
    private let requestMapper: DataLogRequestMapperProtocol
    private let logger: ErrorLoggerProtocol
    private let circuitBreaker: CircuitBreaker
    private let networkMonitor: NetworkMonitor
    private let deadLetterQueue: DeadLetterQueue
    private let offlineQueue: OfflineQueuePersistence
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
        deadLetterQueue: DeadLetterQueue,
        offlineQueue: OfflineQueuePersistence,
        streamingProcessor: StreamingBatchProcessor,
        maxConcurrentUploads: Int = 3,
        maxRetries: Int = 10
    ) {
        self.dataLogService = dataLogService
        self.requestMapper = requestMapper
        self.logger = logger
        self.circuitBreaker = circuitBreaker
        self.networkMonitor = networkMonitor
        self.deadLetterQueue = deadLetterQueue
        self.offlineQueue = offlineQueue
        self.streamingProcessor = streamingProcessor
        self.uploadSemaphore = AsyncSemaphore(value: max(maxConcurrentUploads, 1))
        self.maxRetries = max(maxRetries, 1)
        
        // Inject network monitor into circuit breaker
        Task { [weak circuitBreaker, weak networkMonitor] in
            guard let circuitBreaker, let networkMonitor else { return }
            await circuitBreaker.setNetworkMonitor(networkMonitor)
        }
        
        // Register for network state changes to handle offline→online transitions
        Task { [weak self, weak networkMonitor] in
            guard let self, let networkMonitor else { return }
            await networkMonitor.onStateChange { [weak self] isConnected in
                guard let self else { return }
                if isConnected {
                    Task { [weak self] in
                        await self?.handleNetworkRestoration()
                    }
                }
            }
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
    
    /// Load persisted chunks and dead letter batches from disk
    private func loadPersistedData() async {
        // 1. Load offline queue chunks
        let persistedChunks = await offlineQueue.loadAllChunks()
        for chunk in persistedChunks {
            await chunkQueue.enqueue(chunk)
        }
        
        // 2. Load and retry dead letter batches
        let deadLetterBatches = await deadLetterQueue.retryAll()
        if !deadLetterBatches.isEmpty {
            // Convert dead letter requests back to chunks for retry
            let deadLetterChunk = DataLogChunk(
                requests: deadLetterBatches,
                sizeInBytes: deadLetterBatches.reduce(0) { $0 + (try? JSONEncoder().encode($1).count ?? 1024) },
                priority: .high  // Give dead letter data high priority for retry
            )
            await chunkQueue.enqueue(deadLetterChunk)
        }
        
        // 3. Clear persisted files after loading into memory
        await offlineQueue.clearAll()
        
        print("[DataLogUploader] Loaded \(persistedChunks.count) persisted chunks and \(deadLetterBatches.count) dead letter logs")
    }
    
    /// Handle network restoration - retry failed uploads and resume upload loop
    private func handleNetworkRestoration() async {
        print("[DataLogUploader] Network restored, resuming uploads...")
        
        // Load any persisted data that accumulated while offline
        await loadPersistedData()
        
        // Restart upload loop if it's not running
        await startUploadLoopIfNeeded()
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

    private func uploadChunk(_ chunk: DataLogChunk) async {
        var attempt = 0
        var wasOffline = false

        while attempt < maxRetries && !Task.isCancelled {
            do {
                try Task.checkCancellation()

                // Check if device is offline
                let isOffline = !await networkMonitor.shouldAttemptUpload()
                
                if isOffline {
                    // Persist chunk to disk if going offline
                    if !wasOffline {
                        print("[DataLogUploader] Device offline, persisting chunk with \(chunk.requests.count) logs")
                        await offlineQueue.persistChunk(chunk)
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
                return
            } catch {
                attempt += 1
                await circuitBreaker.recordFailure()
                logger.postError(error)

                // If offline, persist and wait instead of retrying
                if !await networkMonitor.shouldAttemptUpload() {
                    print("[DataLogUploader] Upload failed due to offline state, persisting chunk")
                    await offlineQueue.persistChunk(chunk)
                    return  // Exit retry loop, will be retried on network restoration
                }

                let backoffExponent = Double(min(max(attempt - 1, 0), 4))
                let waitMinutes = pow(2.0, backoffExponent)
                let waitTime = min(TimeInterval.minutes(waitMinutes), TimeInterval.minutes(16))
                try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }

        // Max retries exceeded - send to dead letter queue
        let error = NSError(
            domain: "DataLogUploader",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Max retry attempts exceeded for chunk with priority \(chunk.priority)"]
        )
        logger.postError(error)
        await deadLetterQueue.enqueueFailed(
            batch: chunk.requests,
            error: error,
            attemptCount: attempt
        )
    }

    func dispose() async {
        uploadTask?.cancel()
        uploadTask = nil
        await chunkQueue.clear()
        await networkMonitor.stopMonitoring()
    }
}

private actor ChunkQueue {
    private var storage: [UploadPriority: [DataLogChunk]] = [:]

    func enqueue(_ chunk: DataLogChunk) {
        storage[chunk.priority, default: []].append(chunk)
    }

    func dequeue() -> DataLogChunk? {
        for priority in [UploadPriority.critical, .high, .normal, .low] {
            if var queue = storage[priority], !queue.isEmpty {
                let chunk = queue.removeFirst()
                storage[priority] = queue
                return chunk
            }
        }
        return nil
    }

    func clear() {
        storage.removeAll()
    }
}

