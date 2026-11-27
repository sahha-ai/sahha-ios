import Testing
import Foundation
import UIKit

@testable import Sahha

// Coverage for the UIKit background task each upload loop runs under.
//
// The expiration handler used to only log, and the task ended only once the loop
// had drained the queue. A loop that outlasted the app's background time (a retry
// backoff of a minute or more, a 60-second wait for connectivity, or just a long
// queue) still held its task when the time ran out, and UIKit terminates an app in
// that state. The expiration handler now ends the task and stops the loop. The
// batch in flight goes back on the queue, every batch stays persisted, and the
// next loop sends them under a task of its own.

// MARK: - Test doubles

/// The ordered record of a test: what the fake provider and the upload service did.
private final class EventLog: @unchecked Sendable {
    enum Event: Equatable {
        case began(String)
        case ended(Int)
        case uploadStarted([String])
        case uploadCancelled([String])
        case uploadSent([String])
        case uploadFailed([String])
    }

    private let lock = NSLock()
    private var _events: [Event] = []

    var events: [Event] {
        lock.lock(); defer { lock.unlock() }
        return _events
    }

    func record(_ event: Event) {
        lock.lock(); defer { lock.unlock() }
        _events.append(event)
    }
}

/// Stands in for `UIApplication`: hands out sequential identifiers from 1,
/// records begins and ends, and keeps every expiration handler so a test can
/// fire them.
@MainActor
private final class FakeBackgroundTaskProvider: BackgroundTaskProviding {
    private let log: EventLog
    private let grantsTime: Bool
    private let expiresDuringBegin: Bool
    private var nextIdentifier = 1
    private var expirationHandlers: [@MainActor @Sendable () -> Void] = []

    /// - Parameters:
    ///   - grantsTime: false makes `beginBackgroundTask` return `.invalid`, as
    ///     UIKit does when the app cannot run in the background.
    ///   - expiresDuringBegin: fires the expiration handler inside
    ///     `beginBackgroundTask`, before the identifier is returned.
    nonisolated init(log: EventLog, grantsTime: Bool = true, expiresDuringBegin: Bool = false) {
        self.log = log
        self.grantsTime = grantsTime
        self.expiresDuringBegin = expiresDuringBegin
    }

    func beginBackgroundTask(
        withName name: String,
        expirationHandler: @escaping @MainActor @Sendable () -> Void
    ) -> UIBackgroundTaskIdentifier {
        log.record(.began(name))
        guard grantsTime else { return .invalid }
        let identifier = UIBackgroundTaskIdentifier(rawValue: nextIdentifier)
        nextIdentifier += 1
        expirationHandlers.append(expirationHandler)
        if expiresDuringBegin {
            expirationHandler()
        }
        return identifier
    }

    func endBackgroundTask(_ identifier: UIBackgroundTaskIdentifier) {
        log.record(.ended(identifier.rawValue))
    }

    /// Fires every expiration handler, as UIKit does when background time runs out.
    func expire() {
        for handler in expirationHandlers {
            handler()
        }
    }
}

/// A one-shot signal: `wait()` returns once `open()` has been called.
private actor Latch {
    private(set) var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        for waiter in waiters {
            waiter.resume()
        }
        waiters.removeAll()
    }
}

private func makeRequest(id: String) -> DataLogRequest {
    DataLogRequest(
        id: id,
        logType: "activity",
        dataType: "steps",
        value: 1,
        unit: "count",
        source: "test",
        recordingMethod: "automatic",
        deviceType: "iPhone",
        startDateTime: "2024-01-01T00:00:00.000",
        endDateTime: "2024-01-01T00:00:00.000",
        deviceId: "test-device"
    )
}

private func makeChunk(_ ids: [String]) -> UploadChunk<DataLogRequest> {
    UploadChunk(requests: ids.map { makeRequest(id: $0) }, sizeInBytes: 10, priority: .high)
}

/// Stands in for a request in flight: records its start, opens `started`, then
/// waits up to 10 s for a response. Cancelling the upload loop cuts it short with
/// the error URLSession throws for a cancelled task. `APIClient` rethrows that
/// wrapped in an `APIErrorResponse`; either way it is not a `CancellationError`.
private func slowRequest(_ requests: [DataLogRequest], log: EventLog, started: Latch) async throws {
    let ids = requests.map(\.id)
    log.record(.uploadStarted(ids))
    await started.open()
    try? await Task.sleep(nanoseconds: 10_000_000_000)
    guard !Task.isCancelled else {
        log.record(.uploadCancelled(ids))
        throw URLError(.cancelled)
    }
    log.record(.uploadSent(ids))
}

/// Polls `condition` until it holds or `timeout` elapses; returns the final result.
private func waitUntil(timeout: Double = 5, _ condition: @Sendable () async -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if await condition() { return true }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
    return await condition()
}

// MARK: - Tests

@Suite("Upload loop background task")
struct UploaderBackgroundTaskTests {
    private let taskName = "Sahha.UploaderBackgroundTaskTest.Upload"

    private func makeUploader(
        tempDir: URL,
        provider: FakeBackgroundTaskProvider,
        logger: ErrorLoggerProtocol = NoopErrorLogger(),
        circuitBreaker: CircuitBreaker = CircuitBreaker(),
        uploadService: @escaping @Sendable ([DataLogRequest]) async throws -> Void
    ) -> UnifiedUploader<DataLog, DataLogRequest> {
        UnifiedUploader<DataLog, DataLogRequest>(
            uploadService: uploadService,
            logger: logger,
            circuitBreaker: circuitBreaker,
            networkMonitor: NetworkMonitor(isConnected: true),
            persistentQueue: UnifiedDeadLetterQueue<DataLogRequest>(baseDirectory: tempDir),
            streamingProcessor: StreamingChunkProcessor<DataLog, DataLogRequest>(
                // Unused: these tests drive enqueue(_:) and retryPendingUploads() directly.
                mapItem: { _ in makeRequest(id: "unused") },
                assignPriority: { _ in .normal }
            ),
            sentStore: SentItemStore(storage: InMemoryStorage(), storageKey: "test.sent.\(UUID().uuidString)"),
            backgroundTasks: provider,
            logLabel: "UploaderBackgroundTaskTest"
        )
    }

    private func makeTempDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    @Test("A loop that drains the queue ends its task once; a late expiry changes nothing")
    func drainedLoopEndsTaskOnce() async throws {
        let tempDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let log = EventLog()
        let provider = FakeBackgroundTaskProvider(log: log)
        let uploader = makeUploader(tempDir: tempDir, provider: provider) { requests in
            log.record(.uploadSent(requests.map(\.id)))
        }

        await uploader.enqueue(makeChunk(["a"]))

        #expect(await waitUntil { log.events.contains(.ended(1)) })
        let drained: [EventLog.Event] = [.began(taskName), .uploadSent(["a"]), .ended(1)]
        #expect(log.events == drained)
        #expect(await uploader.getDLQStatistics().totalBatches == 0)

        await provider.expire()
        #expect(log.events == drained)

        await uploader.dispose()
    }

    @Test("Expiry mid-upload ends the task before the expiration handler returns, and stops the loop without counting a failure")
    func expiryMidUploadStopsLoop() async throws {
        let tempDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let log = EventLog()
        let provider = FakeBackgroundTaskProvider(log: log)
        let logger = RecordingErrorLogger()
        let breaker = CircuitBreaker()
        let inFlight = Latch()
        let uploader = makeUploader(tempDir: tempDir, provider: provider, logger: logger, circuitBreaker: breaker) { requests in
            try await slowRequest(requests, log: log, started: inFlight)
        }

        await uploader.enqueue(makeChunk(["a"]))
        try #require(await waitUntil { await inFlight.isOpen }, "The upload never started")

        // UIKit calls the expiration handler synchronously on the main thread and
        // terminates the app if the task is still held when time runs out, so the
        // task must be ended by the time the handler returns.
        await provider.expire()
        #expect(log.events.contains(.ended(1)))

        // The loop stops instead of carrying on without background time, and the
        // request it cut off is not an upload failure: nothing is posted and the
        // circuit breaker is not charged.
        #expect(await waitUntil { !(await uploader.isUploadLoopRunning) })
        #expect(log.events.contains(.uploadCancelled(["a"])))
        #expect(logger.count == 0)
        #expect(await breaker.getState().failures == 0)

        // The batch is still persisted, once, and the task was ended once.
        #expect(await uploader.getDLQStatistics().totalBatches == 1)
        #expect(log.events.filter { $0 == .ended(1) }.count == 1)

        await uploader.dispose()
    }

    @Test("Expiry during a retry backoff stops the loop and posts no max-retries error")
    func expiryDuringBackoffStopsLoop() async throws {
        let tempDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let log = EventLog()
        let provider = FakeBackgroundTaskProvider(log: log)
        let logger = RecordingErrorLogger()
        let uploader = makeUploader(tempDir: tempDir, provider: provider, logger: logger) { requests in
            log.record(.uploadFailed(requests.map(\.id)))
            throw URLError(.badServerResponse)
        }

        await uploader.enqueue(makeChunk(["a"]))

        // The first attempt fails for real, and the loop backs off for a minute
        // before the next: far longer than the background time a wake gets.
        #expect(await waitUntil { logger.count == 1 })

        await provider.expire()
        #expect(log.events.contains(.ended(1)))

        // Stopping is not retry exhaustion: only the genuine failure was posted,
        // no further attempt was made, and the batch is still persisted.
        #expect(await waitUntil { !(await uploader.isUploadLoopRunning) })
        let posted = logger.drain().map { "\($0.error)" }
        #expect(posted.count == 1)
        #expect(!posted.contains { $0.contains("Max retry attempts exceeded") })
        #expect(log.events.filter { $0 == .uploadFailed(["a"]) }.count == 1)
        #expect(await uploader.getDLQStatistics().totalBatches == 1)

        await uploader.dispose()
    }

    @Test("The batch cut off at expiry goes back on the queue, and the next loop sends it under a new task")
    func cutOffBatchIsResentByNextLoop() async throws {
        let tempDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let log = EventLog()
        let provider = FakeBackgroundTaskProvider(log: log)
        let inFlight = Latch()
        // The first attempt at "a" hangs until the loop is stopped; every other
        // upload is sent at once.
        let uploader = makeUploader(tempDir: tempDir, provider: provider) { requests in
            if requests.map(\.id) == ["a"], !log.events.contains(.uploadStarted(["a"])) {
                try await slowRequest(requests, log: log, started: inFlight)
            } else {
                log.record(.uploadSent(requests.map(\.id)))
            }
        }

        await uploader.enqueue(makeChunk(["a"]))
        try #require(await waitUntil { await inFlight.isOpen }, "The upload never started")
        await provider.expire()
        #expect(await waitUntil { !(await uploader.isUploadLoopRunning) })
        #expect(log.events.contains(.ended(1)))
        #expect(log.events.contains(.uploadCancelled(["a"])))
        let atStop = log.events

        // The next enqueue starts a fresh loop under a fresh task, and that loop
        // sends the cut-off batch ahead of the new one.
        await uploader.enqueue(makeChunk(["b"]))
        #expect(await waitUntil { log.events.contains(.ended(2)) })
        #expect(log.events == atStop + [.began(taskName), .uploadSent(["a"]), .uploadSent(["b"]), .ended(2)])
        #expect(await uploader.getDLQStatistics().totalBatches == 0)

        await uploader.dispose()
    }

    /// How the app's next wake reaches the uploader.
    enum Wake: CaseIterable, Sendable {
        /// A resume, foreground or unlock calls `retryPendingUploads()`.
        case retry
        /// New data calls `enqueue(_:)`.
        case enqueue
    }

    @Test(
        "Work that arrives while an expired loop is still stopping starts a fresh loop once it stops",
        arguments: Wake.allCases
    )
    func workDuringStopStartsFreshLoop(wake: Wake) async throws {
        let tempDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let log = EventLog()
        let provider = FakeBackgroundTaskProvider(log: log)
        let inFlight = Latch()
        let stopping = Latch()
        // The first attempt at "a" ignores the cancellation until `stopping` opens,
        // so the expired loop is still stopping when the app next wakes, as it is
        // when iOS suspends the app before the loop gets to finish. Every other
        // upload is sent at once.
        let uploader = makeUploader(tempDir: tempDir, provider: provider) { requests in
            let ids = requests.map(\.id)
            if ids == ["a"], !log.events.contains(.uploadStarted(["a"])) {
                log.record(.uploadStarted(ids))
                await inFlight.open()
                await stopping.wait()
                log.record(.uploadCancelled(ids))
                throw URLError(.cancelled)
            }
            log.record(.uploadSent(ids))
        }

        await uploader.enqueue(makeChunk(["a"]))
        try #require(await waitUntil { await inFlight.isOpen }, "The upload never started")
        await provider.expire()
        #expect(log.events.contains(.ended(1)))
        let atExpiry = log.events

        // The app wakes while the expired loop is still stopping.
        switch wake {
        case .retry:
            await uploader.retryPendingUploads()
        case .enqueue:
            await uploader.enqueue(makeChunk(["b"]))
        }
        #expect(await uploader.isUploadLoopRunning)

        // Once it stops, a fresh loop under a fresh task sends what is queued.
        await stopping.open()
        #expect(
            await waitUntil { log.events.contains(.ended(2)) },
            "No fresh loop started after the expired loop stopped"
        )
        let afterExpiry = log.events.dropFirst(atExpiry.count)
        #expect(afterExpiry.first == EventLog.Event.uploadCancelled(["a"]))
        #expect(afterExpiry.contains(.began(taskName)))
        #expect(afterExpiry.contains(.uploadSent(["a"])))
        if wake == .enqueue {
            #expect(afterExpiry.contains(.uploadSent(["b"])))
        }
        #expect(await waitUntil { !(await uploader.isUploadLoopRunning) })
        #expect(await uploader.getDLQStatistics().totalBatches == 0)

        await uploader.dispose()
    }

    @Test("An expiry inside beginBackgroundTask ends the task once its identifier exists, and the loop sends nothing")
    func expiryDuringBeginStopsLoopBeforeUploading() async throws {
        let tempDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let log = EventLog()
        let provider = FakeBackgroundTaskProvider(log: log, expiresDuringBegin: true)
        let uploader = makeUploader(tempDir: tempDir, provider: provider) { requests in
            log.record(.uploadSent(requests.map(\.id)))
        }

        await uploader.enqueue(makeChunk(["a"]))

        #expect(await waitUntil { !(await uploader.isUploadLoopRunning) })
        #expect(log.events == [.began(taskName), .ended(1)])
        // The batch waits, still persisted, for the next loop.
        #expect(await uploader.getDLQStatistics().totalBatches == 1)

        await uploader.dispose()
    }

    @Test("With no background time granted the loop still sends the batch, and there is no task to end")
    func noBackgroundTimeStillUploads() async throws {
        let tempDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let log = EventLog()
        let provider = FakeBackgroundTaskProvider(log: log, grantsTime: false)
        let uploader = makeUploader(tempDir: tempDir, provider: provider) { requests in
            log.record(.uploadSent(requests.map(\.id)))
        }

        await uploader.enqueue(makeChunk(["a"]))

        #expect(await waitUntil { !(await uploader.isUploadLoopRunning) })
        #expect(log.events == [.began(taskName), .uploadSent(["a"])])
        #expect(await uploader.getDLQStatistics().totalBatches == 0)

        await uploader.dispose()
    }

    @Test("Dispose mid-upload still ends the task, once")
    func disposeMidUploadEndsTask() async throws {
        let tempDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let log = EventLog()
        let provider = FakeBackgroundTaskProvider(log: log)
        let logger = RecordingErrorLogger()
        let inFlight = Latch()
        let uploader = makeUploader(tempDir: tempDir, provider: provider, logger: logger) { requests in
            try await slowRequest(requests, log: log, started: inFlight)
        }

        await uploader.enqueue(makeChunk(["a"]))
        try #require(await waitUntil { await inFlight.isOpen }, "The upload never started")

        // Deauthentication: dispose cancels the loop, and the task ends with it.
        await uploader.dispose()
        #expect(await waitUntil { log.events.contains(.ended(1)) })
        #expect(log.events.contains(.uploadCancelled(["a"])))
        #expect(logger.count == 0)

        let atEnd = log.events
        await provider.expire()
        #expect(log.events == atEnd)
    }
}
