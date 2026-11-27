import Foundation

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
    private let backgroundTasks: BackgroundTaskProviding
    private let uploadSemaphore: AsyncSemaphore
    private let maxRetries: Int
    private let logLabel: String
    private let chunkQueue = PriorityChunkQueue<Request>()
    private var uploadTask: Task<Void, Never>? = nil
    /// Set when work arrives while a loop that expiry cancelled is still stopping.
    /// That loop won't pick the work up, so it starts a fresh loop as it stops.
    private var startLoopWhenStopped = false
    private var hasLoadedPersistedData = false
    /// Latched by `dispose()` (container teardown, e.g. deauthentication). An upload
    /// flight that resolves after teardown must not write batches back into the
    /// just-purged dead-letter queue — that would resurrect upload state behind the
    /// fresh container's back.
    private var disposed = false

    init(
        uploadService: @escaping @Sendable ([Request]) async throws -> Void,
        logger: ErrorLoggerProtocol,
        circuitBreaker: CircuitBreaker,
        networkMonitor: NetworkMonitor,
        persistentQueue: UnifiedDeadLetterQueue<Request>,
        streamingProcessor: StreamingChunkProcessor<Item, Request>,
        sentStore: SentItemStore,
        backgroundTasks: BackgroundTaskProviding = UIKitBackgroundTaskProvider(),
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
        self.backgroundTasks = backgroundTasks
        self.logLabel = logLabel
        self.uploadSemaphore = AsyncSemaphore(value: max(config.maxConcurrentUploads, 1))
        self.maxRetries = max(config.maxRetries, 1)

        Task { [weak circuitBreaker, weak networkMonitor] in
            guard let circuitBreaker, let networkMonitor else { return }
            await circuitBreaker.setNetworkMonitor(networkMonitor)
        }
    }

    func enqueue(_ chunk: UploadChunk<Request>) async {
        guard !disposed else { return }
        let persistedId = await persistentQueue.persistBatch(chunk, attemptCount: 0, lastError: nil)
        await chunkQueue.enqueue(chunk, persistedId: persistedId)
        startUploadLoopIfNeeded()
    }

    func enqueueItems(_ items: [Item]) async {
        guard !disposed else { return }
        await streamingProcessor.streamChunks(from: items) { [weak self] chunk in
            guard let self else { return }
            await self.enqueue(chunk)
        }
    }

    func retryPendingUploads() async {
        guard !disposed else { return }
        if let uploadTask {
            if uploadTask.isCancelled {
                // A loop that expiry cancelled can still be stopping when the app
                // next wakes: iOS may suspend the app before the loop clears
                // uploadTask. It won't pick anything up, so it starts a fresh loop
                // as it stops (see runUploadLoop).
                startLoopWhenStopped = true
                Sahha.log("[\(logLabel)] Upload loop is stopping; a fresh loop starts once it has")
            } else {
                Sahha.log("[\(logLabel)] Upload loop already running, skipping retry")
            }
            return
        }

        // This reads the whole dead-letter queue, including whatever earlier
        // processes left there, so the loop it starts has no need to read it again.
        hasLoadedPersistedData = true
        let persistedBatches = await persistentQueue.loadAllBatches()
        guard !disposed else { return }
        guard !persistedBatches.isEmpty else {
            Sahha.log("[\(logLabel)] No pending batches to retry")
            return
        }

        Sahha.log("[\(logLabel)] Retrying \(persistedBatches.count) pending batches on app wake")
        // A batch already queued or being uploaded (a loop may have started during
        // the read above) is skipped: see PriorityChunkQueue.
        for batch in persistedBatches {
            await chunkQueue.enqueue(batch.chunk, persistedId: batch.id)
        }
        startUploadLoopIfNeeded()
    }

    func getDLQStatistics() async -> PersistenceStatistics {
        await persistentQueue.getStatistics()
    }

    /// Whether an upload loop is running. Tests use it to tell when a loop has
    /// stopped.
    var isUploadLoopRunning: Bool {
        uploadTask != nil
    }

    /// How many chunks are waiting in the queue, not counting one being uploaded.
    /// Tests use it to check that no chunk is queued twice.
    var queuedChunkCount: Int {
        get async { await chunkQueue.count }
    }

    func dispose() async {
        disposed = true
        startLoopWhenStopped = false
        uploadTask?.cancel()
        uploadTask = nil
        await chunkQueue.clear()
        await persistentQueue.clearAll()
        // Clear the sent-ID dedup store too. On deauthentication the container is
        // reset and anchors are wiped, so the next session re-queries history from
        // scratch. If the dedup store survived, those re-queried items would be
        // filtered as "already sent" and never re-uploaded — only genuinely new
        // samples (e.g. a fresh night of sleep) would get through.
        await sentStore.dispose()
        await networkMonitor.stopMonitoring()
    }

    // MARK: - Upload Loop

    /// Starts an upload loop unless one is running. It is synchronous on purpose:
    /// with no suspension point between the check of `uploadTask` and setting it,
    /// two callers can't both find no loop and both start one. They used to, when
    /// the first loop of a process awaited its read of the dead-letter queue here
    /// and a second enqueue arrived meanwhile (two sensors' observers firing on the
    /// same background wake). The two loops then sent the same chunks at the same
    /// time, before either marked them sent, so each reached the server twice.
    private func startUploadLoopIfNeeded() {
        guard !disposed else { return }
        if let uploadTask {
            // As in retryPendingUploads: a loop that expiry cancelled won't dequeue
            // this work, so it starts a fresh loop as it stops.
            if uploadTask.isCancelled { startLoopWhenStopped = true }
            return
        }

        let expiry = CancellationRelay()
        let task = Task { [weak self] in
            guard let self else { return }

            // The loop runs under a UIKit background task, and UIKit terminates an
            // app that still holds one when its background time runs out. A loop
            // easily outlasts that time: a failed upload backs off for a minute or
            // more, and offline the loop waits up to 60 seconds for connectivity.
            // So the lease ends the task from the expiration handler if the loop
            // hasn't finished by then.
            //
            // The lease's `onEnd` also stops the loop at expiry. Stopping loses
            // nothing. The batch in flight goes back on the queue (see
            // runUploadLoop), the batches behind it stay there, and each keeps the
            // file written when it was enqueued, which is removed only once it has
            // been sent. The next loop, started by the next enqueue or by
            // retryPendingUploads() on the next resume, foreground or unlock, sends
            // them under a background task of its own, and after a relaunch they
            // are loaded from their files. Left running, the loop would freeze when
            // the app suspends and carry on at the next wake without a background
            // task, and since uploadTask would still be set, no new loop could
            // begin one either. The request it was in the middle of would also
            // likely come back as a failure, counted against the circuit breaker
            // and posted as an error.
            //
            // When the loop finishes first, `onEnd` runs as the task ends and
            // cancels a loop that has already returned, which does nothing.
            let backgroundTask = await BackgroundTaskLease.begin(
                named: "Sahha.\(self.logLabel).Upload",
                provider: self.backgroundTasks,
                onEnd: { expiry.cancel() }
            )

            // The first loop of a process also queues the batches earlier processes
            // left in the dead-letter queue. It does so even when expiry has
            // already stopped it, so that the next loop finds them queued.
            await self.loadPersistedDataIfNeeded()
            await self.networkMonitor.startMonitoring()
            await self.runUploadLoop()

            await backgroundTask.end()
        }
        // The relay also covers an expiry that runs inside beginBackgroundTask,
        // before this line: it cancels the task as it is registered.
        expiry.register(task)
        uploadTask = task
    }

    private func loadPersistedDataIfNeeded() async {
        guard !hasLoadedPersistedData else { return }
        hasLoadedPersistedData = true

        let persistedBatches = await persistentQueue.loadAllBatches()
        guard !disposed else { return }

        // The read also finds the chunks this process has persisted, such as the
        // one whose enqueue started this loop. Those are queued already, so they
        // are skipped: see PriorityChunkQueue.
        var alreadyQueuedCount = 0
        for batch in persistedBatches {
            if !(await chunkQueue.enqueue(batch.chunk, persistedId: batch.id)) {
                alreadyQueuedCount += 1
            }
        }

        let failedCount = persistedBatches.filter { $0.hasFailed }.count
        Sahha.log("[\(logLabel)] Loaded \(persistedBatches.count) persisted batches (\(alreadyQueuedCount) already queued, \(failedCount) previously failed)")
    }

    private func runUploadLoop() async {
        while !Task.isCancelled {
            guard let chunk = await chunkQueue.dequeue() else {
                break
            }

            await uploadSemaphore.wait()
            await uploadChunk(chunk)
            await uploadSemaphore.signal()

            // Cancelled but not disposed: the background task ran out (see
            // startUploadLoopIfNeeded), possibly in the middle of this batch. Put
            // it back so the next loop resends it. Its file is still on disk unless
            // it was sent after all, and then the next loop finds its IDs in the
            // sent store and drops it.
            if Task.isCancelled, !disposed {
                await chunkQueue.requeue(chunk)
            } else {
                await chunkQueue.finish(chunk)
            }
        }
        await networkMonitor.stopMonitoring()
        uploadTask = nil
        // Work arrived while this loop was stopping after expiry, so the app is
        // awake again: start a fresh loop, under a background task of its own.
        if startLoopWhenStopped {
            startLoopWhenStopped = false
            startUploadLoopIfNeeded()
        }
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

                // Teardown can interleave at the await above. A disposed uploader's
                // queue has just been purged; persisting or uploading anything more
                // would write state back behind the fresh container.
                guard !disposed else { return }

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
            } catch is CancellationError {
                // Cancellation is teardown (dispose cancels the upload loop) or the
                // end of the loop's background time, not an upload failure: no retry
                // accounting, no circuit-breaker penalty, no error post, and nothing
                // written back to the queue. After dispose the queue was just purged;
                // after expiry the batch is still persisted and runUploadLoop
                // requeues it.
                return
            } catch {
                // A request cut off by that cancellation doesn't throw
                // CancellationError: URLSession throws URLError(.cancelled), which
                // APIClient wraps in an APIErrorResponse. Whatever a cancelled loop's
                // upload throws is the cancellation, not a failure.
                guard !disposed, !Task.isCancelled else { return }
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

        // The loop also exits on cancellation (dispose, or the background task running
        // out, interrupts the backoff sleep). That is not retry exhaustion, so a "max
        // retries" error would be bogus. Nor should the batch be persisted again: after
        // dispose the queue was just purged, so that would resurrect it, and after
        // expiry it is still persisted and runUploadLoop requeues it.
        guard !disposed, !Task.isCancelled else { return }

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
    /// The persisted IDs of the batches that are queued or being uploaded.
    ///
    /// A batch can reach the queue more than once: the enqueue that persists it
    /// queues it, and so can any read of the dead-letter queue that finds its file
    /// (the first loop of a process, `retryPendingUploads()`). The loop would then
    /// handle the batch twice: the sent store skips the second copy once the first
    /// is sent, but a batch whose upload fails is retried twice over.
    private var tracked: Set<String> = []

    /// Queues `chunk`, unless the batch persisted as `persistedId` is already
    /// queued or being uploaded. Returns whether it was queued.
    @discardableResult
    func enqueue(_ chunk: UploadChunk<Request>, persistedId: String? = nil) -> Bool {
        if let persistedId {
            guard tracked.insert(persistedId).inserted else { return false }
        }
        let item = QueuedChunk(chunk: chunk, persistedId: persistedId)
        storage[chunk.priority, default: []].append(item)
        return true
    }

    /// Puts back a chunk taken by `dequeue()`, at the end of its priority's queue.
    func requeue(_ item: QueuedChunk<Request>) {
        storage[item.chunk.priority, default: []].append(item)
    }

    /// Done with a chunk taken by `dequeue()`: it was sent, or skipped as already
    /// sent, or failed and stays in the dead-letter queue. A later read of that
    /// queue may queue it again.
    func finish(_ item: QueuedChunk<Request>) {
        if let persistedId = item.persistedId {
            tracked.remove(persistedId)
        }
    }

    /// Takes the next chunk, highest priority first. Its batch still counts as
    /// queued until `finish(_:)` or `requeue(_:)`.
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

    var count: Int {
        storage.values.reduce(0) { $0 + $1.count }
    }

    func clear() {
        storage.removeAll()
        tracked.removeAll()
    }
}
