import Foundation
import UIKit

/// Generic uploader that handles the full upload lifecycle for any data type:
/// ingestion → batching → priority queuing → upload with retry → dead letter queue.
///
/// Uses exponential backoff, circuit breaker, network monitoring, and async
/// semaphore concurrency control — identical behavior to the legacy uploaders.
actor UnifiedUploader<Item: Sendable, Request: UploadableRequest>: Disposable {
    private let uploadService: @Sendable ([Request]) async throws -> Void
    private let logger: ErrorLoggerProtocol
    private let circuitBreaker: CircuitBreaker
    private let networkMonitor: NetworkMonitor
    private let persistentQueue: UnifiedDeadLetterQueue<Request>
    private let streamingProcessor: StreamingChunkProcessor<Item, Request>
    private let sentStore: SentItemStore
    private let uploadSemaphore: AsyncSemaphore
    private let maxRetries: Int
    private let logLabel: String
    private let chunkQueue = PriorityChunkQueue<Request>()
    private var uploadTask: Task<Void, Never>? = nil
    private var hasLoadedPersistedData = false

    init(
        uploadService: @escaping @Sendable ([Request]) async throws -> Void,
        logger: ErrorLoggerProtocol,
        circuitBreaker: CircuitBreaker,
        networkMonitor: NetworkMonitor,
        persistentQueue: UnifiedDeadLetterQueue<Request>,
        streamingProcessor: StreamingChunkProcessor<Item, Request>,
        sentStore: SentItemStore,
        logLabel: String = "UnifiedUploader",
        config: UploadConfig = .default
    ) {
        self.uploadService = uploadService
        self.logger = logger
        self.circuitBreaker = circuitBreaker
        self.networkMonitor = networkMonitor
        self.persistentQueue = persistentQueue
        self.streamingProcessor = streamingProcessor
        self.sentStore = sentStore
        self.logLabel = logLabel
        self.uploadSemaphore = AsyncSemaphore(value: max(config.maxConcurrentUploads, 1))
        self.maxRetries = max(config.maxRetries, 1)

        Task { [weak circuitBreaker, weak networkMonitor] in
            guard let circuitBreaker, let networkMonitor else { return }
            await circuitBreaker.setNetworkMonitor(networkMonitor)
        }
    }

    func enqueue(_ chunk: UploadChunk<Request>) async {
        let persistedId = await persistentQueue.persistBatch(chunk, attemptCount: 0, lastError: nil)
        await chunkQueue.enqueue(chunk, persistedId: persistedId)
        await startUploadLoopIfNeeded()
    }

    func enqueueItems(_ items: [Item]) async {
        await streamingProcessor.streamChunks(from: items) { [weak self] chunk in
            guard let self else { return }
            await self.enqueue(chunk)
        }
    }

    func retryPendingUploads() async {
        guard uploadTask == nil else {
            Sahha.log("[\(logLabel)] Upload loop already running, skipping retry")
            return
        }

        let persistedBatches = await persistentQueue.loadAllBatches()
        guard !persistedBatches.isEmpty else {
            Sahha.log("[\(logLabel)] No pending batches to retry")
            return
        }

        Sahha.log("[\(logLabel)] Retrying \(persistedBatches.count) pending batches on app wake")
        for batch in persistedBatches {
            await chunkQueue.enqueue(batch.chunk, persistedId: batch.id)
        }
        await startUploadLoopIfNeeded()
    }

    func dispose() async {
        uploadTask?.cancel()
        uploadTask = nil
        await chunkQueue.clear()
        await networkMonitor.stopMonitoring()
    }

    // MARK: - Upload Loop

    private func startUploadLoopIfNeeded() async {
        guard uploadTask == nil else { return }

        if !hasLoadedPersistedData {
            await loadPersistedData()
            hasLoadedPersistedData = true
        }

        uploadTask = Task { [weak self] in
            guard let self else { return }

            let bgTaskId = await Self.beginUploadBackgroundTask(label: self.logLabel)

            await self.networkMonitor.startMonitoring()
            await self.runUploadLoop()

            Self.endUploadBackgroundTask(bgTaskId)
        }
    }

    @MainActor
    private static func beginUploadBackgroundTask(label: String) -> UIBackgroundTaskIdentifier {
        return UIApplication.shared.beginBackgroundTask(withName: "Sahha.\(label).Upload") {
            Sahha.log("[\(label)] Background upload task expiring")
        }
    }

    private static func endUploadBackgroundTask(_ taskId: UIBackgroundTaskIdentifier) {
        guard taskId != .invalid else { return }
        Task { @MainActor in
            UIApplication.shared.endBackgroundTask(taskId)
        }
    }

    private func loadPersistedData() async {
        let persistedBatches = await persistentQueue.loadAllBatches()

        for batch in persistedBatches {
            await chunkQueue.enqueue(batch.chunk, persistedId: batch.id)
        }

        let failedCount = persistedBatches.filter { $0.hasFailed }.count
        Sahha.log("[\(logLabel)] Loaded \(persistedBatches.count) persisted batches (\(failedCount) previously failed)")
    }

    private func runUploadLoop() async {
        while !Task.isCancelled {
            guard let chunk = await chunkQueue.dequeue() else {
                break
            }

            await uploadSemaphore.wait()
            await uploadChunk(chunk)
            await uploadSemaphore.signal()
        }
        await networkMonitor.stopMonitoring()
        uploadTask = nil
    }

    private func uploadChunk(_ queuedChunk: QueuedChunk<Request>) async {
        let originalChunk = queuedChunk.chunk
        var persistedIds = Set<String>()
        if let id = queuedChunk.persistedId {
            persistedIds.insert(id)
        }
        var attempt = 0
        var wasOffline = false

        let unsentRequests = await sentStore.filterUnsentRequests(originalChunk.requests)

        guard !unsentRequests.isEmpty else {
            Sahha.log("[\(logLabel)] All \(originalChunk.requests.count) items in chunk already sent, skipping")
            for id in persistedIds {
                await persistentQueue.removeBatch(withId: id)
            }
            return
        }

        let chunk = UploadChunk<Request>(
            requests: unsentRequests,
            sizeInBytes: originalChunk.sizeInBytes,
            priority: originalChunk.priority
        )

        let filteredCount = originalChunk.requests.count - unsentRequests.count
        if filteredCount > 0 {
            Sahha.log("[\(logLabel)] Filtered out \(filteredCount) already-sent items, uploading \(unsentRequests.count)")
        }

        while attempt < maxRetries && !Task.isCancelled {
            do {
                try Task.checkCancellation()

                let isOffline = !(await networkMonitor.shouldAttemptUpload())

                if isOffline {
                    if !wasOffline {
                        Sahha.log("[\(logLabel)] Device offline, persisting chunk with \(chunk.requests.count) items")
                        if let id = await persistentQueue.persistBatch(
                            chunk,
                            attemptCount: attempt,
                            lastError: nil
                        ) {
                            persistedIds.insert(id)
                        }
                        wasOffline = true
                    }

                    try await networkMonitor.waitForConnectivity(timeout: 60)

                    Sahha.log("[\(logLabel)] Network restored, resuming upload for chunk")
                    wasOffline = false
                    continue
                }

                guard await circuitBreaker.shouldAllowRequest() else {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    continue
                }

                try await uploadService(chunk.requests)
                await circuitBreaker.recordSuccess()

                let sentIds = chunk.requests.map { $0.id }
                await sentStore.markSent(sentIds)

                Sahha.log("[\(logLabel)] Successfully uploaded chunk with \(chunk.requests.count) items (priority: \(chunk.priority))")
                for id in persistedIds {
                    await persistentQueue.removeBatch(withId: id)
                }
                return
            } catch {
                attempt += 1
                await circuitBreaker.recordFailure()
                logger.postError(error)

                if !(await networkMonitor.shouldAttemptUpload()) {
                    Sahha.log("[\(logLabel)] Upload failed due to offline state, persisting chunk")
                    _ = await persistentQueue.persistBatch(
                        chunk,
                        attemptCount: attempt,
                        lastError: nil
                    )
                    Sahha.scheduleBackgroundRefreshIfNeeded(timeInterval: 300)
                    return
                }

                let backoffExponent = Double(min(max(attempt - 1, 0), 4))
                let waitMinutes = pow(2.0, backoffExponent)
                let waitTime = min(TimeInterval.minutes(waitMinutes), TimeInterval.minutes(16))
                try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }

        let errorMessage = "Max retry attempts exceeded for chunk with priority \(chunk.priority)"
        let error = NSError(
            domain: logLabel,
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: errorMessage]
        )
        logger.postError(error)

        _ = await persistentQueue.persistBatch(
            chunk,
            attemptCount: attempt,
            lastError: errorMessage
        )

        Sahha.scheduleBackgroundRefreshIfNeeded(timeInterval: 900)
    }
}

// MARK: - Priority Chunk Queue

private struct QueuedChunk<Request: UploadableRequest> {
    let chunk: UploadChunk<Request>
    let persistedId: String?
}

private actor PriorityChunkQueue<Request: UploadableRequest> {
    private var storage: [UploadPriority: [QueuedChunk<Request>]] = [:]

    func enqueue(_ chunk: UploadChunk<Request>, persistedId: String? = nil) {
        let item = QueuedChunk(chunk: chunk, persistedId: persistedId)
        storage[chunk.priority, default: []].append(item)
    }

    func dequeue() -> QueuedChunk<Request>? {
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
