import Foundation
import UIKit

actor TagUploader: TagUploaderProtocol, Disposable {
    private let tagService: TagServiceProtocol
    private let requestMapper: TagRequestMapperProtocol
    private let logger: ErrorLoggerProtocol
    private let circuitBreaker: CircuitBreaker
    private let networkMonitor: NetworkMonitor
    private let persistentQueue: TagDeadLetterQueue
    private let streamingProcessor: StreamingTagBatchProcessor
    private let sentTagStore: SentTagStore
    private let uploadSemaphore: AsyncSemaphore
    private let maxRetries: Int
    private let chunkQueue = TagChunkQueue()
    private var uploadTask: Task<Void, Never>? = nil
    private var hasLoadedPersistedData = false

    init(
        tagService: TagServiceProtocol,
        requestMapper: TagRequestMapperProtocol,
        logger: ErrorLoggerProtocol,
        circuitBreaker: CircuitBreaker,
        networkMonitor: NetworkMonitor,
        persistentQueue: TagDeadLetterQueue,
        streamingProcessor: StreamingTagBatchProcessor,
        sentTagStore: SentTagStore,
        config: UploadConfig = .default
    ) {
        self.tagService = tagService
        self.requestMapper = requestMapper
        self.logger = logger
        self.circuitBreaker = circuitBreaker
        self.networkMonitor = networkMonitor
        self.persistentQueue = persistentQueue
        self.streamingProcessor = streamingProcessor
        self.sentTagStore = sentTagStore
        self.uploadSemaphore = AsyncSemaphore(value: max(config.maxConcurrentUploads, 1))
        self.maxRetries = max(config.maxRetries, 1)

        Task { [weak circuitBreaker, weak networkMonitor] in
            guard let circuitBreaker, let networkMonitor else { return }
            await circuitBreaker.setNetworkMonitor(networkMonitor)
        }
    }

    func enqueue(_ chunk: TagChunk) async {
        let persistedId = await persistentQueue.persistBatch(chunk, attemptCount: 0, lastError: nil)
        await chunkQueue.enqueue(chunk, persistedId: persistedId)
        await startUploadLoopIfNeeded()
    }

    func enqueueTags(_ tags: [Tag]) async {
        await streamingProcessor.streamChunks(from: tags) { [weak self] chunk in
            guard let self else { return }
            await self.enqueue(chunk)
        }
    }

    private func startUploadLoopIfNeeded() async {
        guard uploadTask == nil else { return }

        if !hasLoadedPersistedData {
            await loadPersistedData()
            hasLoadedPersistedData = true
        }

        uploadTask = Task { [weak self] in
            guard let self else { return }

            let bgTaskId = await Self.beginUploadBackgroundTask()

            await self.networkMonitor.startMonitoring()
            await self.runUploadLoop()

            Self.endUploadBackgroundTask(bgTaskId)
        }
    }

    @MainActor
    private static func beginUploadBackgroundTask() -> UIBackgroundTaskIdentifier {
        return UIApplication.shared.beginBackgroundTask(withName: "Sahha.Tag.Upload") {
            Sahha.log("[TagUploader] Background upload task expiring")
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
        Sahha.log("[TagUploader] Loaded \(persistedBatches.count) persisted batches (\(failedCount) previously failed)")
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

    private func uploadChunk(_ queuedChunk: QueuedTagChunk) async {
        let originalChunk = queuedChunk.chunk
        var persistedIds = Set<String>()
        if let id = queuedChunk.persistedId {
            persistedIds.insert(id)
        }
        var attempt = 0
        var wasOffline = false

        let unsentRequests = await sentTagStore.filterUnsentRequests(originalChunk.requests)

        guard !unsentRequests.isEmpty else {
            Sahha.log("[TagUploader] All \(originalChunk.requests.count) tags in chunk already sent, skipping")
            for id in persistedIds {
                await persistentQueue.removeBatch(withId: id)
            }
            return
        }

        let chunk = TagChunk(
            requests: unsentRequests,
            sizeInBytes: originalChunk.sizeInBytes,
            priority: originalChunk.priority
        )

        let filteredCount = originalChunk.requests.count - unsentRequests.count
        if filteredCount > 0 {
            Sahha.log("[TagUploader] Filtered out \(filteredCount) already-sent tags, uploading \(unsentRequests.count)")
        }

        while attempt < maxRetries && !Task.isCancelled {
            do {
                try Task.checkCancellation()

                let isOffline = !(await networkMonitor.shouldAttemptUpload())

                if isOffline {
                    if !wasOffline {
                        Sahha.log("[TagUploader] Device offline, persisting chunk with \(chunk.requests.count) tags")
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

                    Sahha.log("[TagUploader] Network restored, resuming upload for chunk")
                    wasOffline = false
                    continue
                }

                guard await circuitBreaker.shouldAllowRequest() else {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    continue
                }

                try await tagService.postTags(chunk.requests)
                await circuitBreaker.recordSuccess()

                let sentIds = chunk.requests.map { $0.id }
                await sentTagStore.markSent(sentIds)

                Sahha.log("[TagUploader] Successfully uploaded chunk with \(chunk.requests.count) tags (priority: \(chunk.priority))")
                for id in persistedIds {
                    await persistentQueue.removeBatch(withId: id)
                }
                return
            } catch {
                attempt += 1
                await circuitBreaker.recordFailure()
                logger.postError(error)

                if !(await networkMonitor.shouldAttemptUpload()) {
                    Sahha.log("[TagUploader] Upload failed due to offline state, persisting chunk")
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

        let errorMessage = "Max retry attempts exceeded for tag chunk with priority \(chunk.priority)"
        let error = NSError(
            domain: "TagUploader",
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

    func retryPendingUploads() async {
        guard uploadTask == nil else {
            Sahha.log("[TagUploader] Upload loop already running, skipping retry")
            return
        }

        let persistedBatches = await persistentQueue.loadAllBatches()
        guard !persistedBatches.isEmpty else {
            Sahha.log("[TagUploader] No pending batches to retry")
            return
        }

        Sahha.log("[TagUploader] Retrying \(persistedBatches.count) pending batches on app wake")
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
}

private struct QueuedTagChunk {
    let chunk: TagChunk
    let persistedId: String?
}

private actor TagChunkQueue {
    private var storage: [TagPriority: [QueuedTagChunk]] = [:]

    func enqueue(_ chunk: TagChunk, persistedId: String? = nil) {
        let item = QueuedTagChunk(chunk: chunk, persistedId: persistedId)
        storage[chunk.priority, default: []].append(item)
    }

    func dequeue() -> QueuedTagChunk? {
        for priority in [TagPriority.critical, .high, .normal, .low] {
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
