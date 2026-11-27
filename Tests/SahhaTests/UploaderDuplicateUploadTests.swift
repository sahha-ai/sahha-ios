import Testing
import Foundation
import UIKit

@testable import Sahha

// Coverage for duplicate uploads from the first loop of a newly started process.
//
// Seen on a background wake (iPhone 14, iOS 27.2.1): iOS relaunched the app, steps
// and heart rate were collected at the same moment, and every chunk reached the
// server twice. Two faults combined:
//
// 1. The first upload loop of a process loads every batch from the dead-letter
//    queue, and that includes the chunk just persisted and queued by the enqueue
//    that started the loop. The second copy was normally dropped later by the sent
//    store, after a wasted pass.
// 2. `startUploadLoopIfNeeded()` checked for a running loop, then awaited that
//    load before starting one. A second enqueue arriving during the await (two
//    sensors' observers firing together) also loaded the queue and started a
//    second loop. The two loops sent the same chunks at the same time, before
//    either marked them sent.

// MARK: - Test doubles

/// Records the IDs of every upload the service is asked to make, as it starts,
/// and the most uploads that were ever in flight at once.
private final class UploadRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _uploads: [[String]] = []
    private var inFlight = 0
    private var _maxInFlight = 0

    var uploads: [[String]] {
        lock.lock(); defer { lock.unlock() }
        return _uploads
    }

    var uploadedIds: [String] { uploads.flatMap { $0 } }

    /// One upload loop sends one chunk at a time, so more than one upload in
    /// flight means more than one loop.
    var maxInFlight: Int {
        lock.lock(); defer { lock.unlock() }
        return _maxInFlight
    }

    func record(_ requests: [DataLogRequest]) {
        lock.lock(); defer { lock.unlock() }
        _uploads.append(requests.map(\.id))
    }

    func began(_ requests: [DataLogRequest]) {
        lock.lock(); defer { lock.unlock() }
        _uploads.append(requests.map(\.id))
        inFlight += 1
        _maxInFlight = max(_maxInFlight, inFlight)
    }

    func ended() {
        lock.lock(); defer { lock.unlock() }
        inFlight -= 1
    }
}

/// Grants background time for every loop and ignores its end.
private struct GrantingBackgroundTaskProvider: BackgroundTaskProviding {
    @MainActor
    func beginBackgroundTask(
        withName name: String,
        expirationHandler: @escaping @MainActor @Sendable () -> Void
    ) -> UIBackgroundTaskIdentifier {
        UIBackgroundTaskIdentifier(rawValue: 1)
    }

    @MainActor
    func endBackgroundTask(_ identifier: UIBackgroundTaskIdentifier) {}
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

private func makeChunk(_ ids: [String], priority: UploadPriority) -> UploadChunk<DataLogRequest> {
    UploadChunk(requests: ids.map { makeRequest(id: $0) }, sizeInBytes: 10, priority: priority)
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

@Suite("Upload loop duplicate uploads")
struct UploaderDuplicateUploadTests {

    private func makeUploader(
        tempDir: URL,
        uploadService: @escaping @Sendable ([DataLogRequest]) async throws -> Void
    ) -> UnifiedUploader<DataLog, DataLogRequest> {
        UnifiedUploader<DataLog, DataLogRequest>(
            uploadService: uploadService,
            logger: NoopErrorLogger(),
            circuitBreaker: CircuitBreaker(),
            networkMonitor: NetworkMonitor(isConnected: true),
            persistentQueue: UnifiedDeadLetterQueue<DataLogRequest>(baseDirectory: tempDir),
            streamingProcessor: StreamingChunkProcessor<DataLog, DataLogRequest>(
                // Unused: these tests drive enqueue(_:) and retryPendingUploads() directly.
                mapItem: { _ in makeRequest(id: "unused") },
                assignPriority: { _ in .normal }
            ),
            sentStore: SentItemStore(storage: InMemoryStorage(), storageKey: "test.sent.\(UUID().uuidString)"),
            backgroundTasks: GrantingBackgroundTaskProvider(),
            logLabel: "UploaderDuplicateUploadTest"
        )
    }

    private func makeTempDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    /// How a wake reaches a freshly started uploader.
    enum Wake: CaseIterable, Sendable {
        /// New data calls `enqueue(_:)`.
        case enqueue
        /// A resume, foreground or unlock calls `retryPendingUploads()`.
        case retry
    }

    @Test("The first loop of a process queues each batch once", arguments: Wake.allCases)
    func firstLoopQueuesEachBatchOnce(wake: Wake) async throws {
        let tempDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let recorder = UploadRecorder()
        let inFlight = Latch()
        let release = Latch()
        // The first upload holds until `release` opens, so the test can look at
        // what else is queued while it is in flight.
        let uploader = makeUploader(tempDir: tempDir) { requests in
            let isFirst = recorder.uploads.isEmpty
            recorder.record(requests)
            if isFirst {
                await inFlight.open()
                await release.wait()
            }
        }

        switch wake {
        case .enqueue:
            // A new chunk, persisted and queued by the enqueue that starts the loop.
            await uploader.enqueue(makeChunk(["a"], priority: .high))
        case .retry:
            // A batch an earlier process left in the dead-letter queue.
            await UnifiedDeadLetterQueue<DataLogRequest>(baseDirectory: tempDir)
                .persistBatch(makeChunk(["a"], priority: .high))
            await uploader.retryPendingUploads()
        }

        try #require(await waitUntil { await inFlight.isOpen }, "The upload never started")
        // "a" is in flight, and it is the only batch there is: nothing else may
        // be queued behind it.
        #expect(await uploader.queuedChunkCount == 0, "The batch in flight was queued a second time")

        await release.open()
        #expect(await waitUntil { await uploader.getDLQStatistics().totalBatches == 0 })
        #expect(await waitUntil { !(await uploader.isUploadLoopRunning) })
        #expect(recorder.uploads == [["a"]])

        await uploader.dispose()
    }

    /// Two things that wake the uploader at the same moment.
    enum SimultaneousWakes: CaseIterable, Sendable {
        /// Two sensors' observers fire together, as steps and heart rate did.
        case twoEnqueues
        /// A resume retries pending uploads as an observer delivers new data.
        case retryAndEnqueue
    }

    @Test(
        "Two wakes at once on a freshly started uploader send every item exactly once",
        arguments: SimultaneousWakes.allCases
    )
    func simultaneousWakesSendEachItemOnce(wakes: SimultaneousWakes) async throws {
        // The race depends on how the two calls interleave, so run it a few times.
        for round in 1...10 {
            let tempDir = makeTempDir()
            defer { try? FileManager.default.removeItem(at: tempDir) }

            // A batch an earlier process left behind, which this process must
            // still send, once.
            await UnifiedDeadLetterQueue<DataLogRequest>(baseDirectory: tempDir)
                .persistBatch(makeChunk(["earlier"], priority: .normal))

            let recorder = UploadRecorder()
            // Each upload takes a moment, as a network round trip does. A second
            // loop sending the same chunk overlaps it, before the first marks the
            // chunk sent.
            let uploader = makeUploader(tempDir: tempDir) { requests in
                recorder.began(requests)
                try? await Task.sleep(nanoseconds: 20_000_000)
                recorder.ended()
            }

            let steps = makeChunk(["steps-1"], priority: .critical)
            let heartRate = makeChunk(["hr-1", "hr-2"], priority: .high)
            switch wakes {
            case .twoEnqueues:
                async let first: Void = uploader.enqueue(steps)
                async let second: Void = uploader.enqueue(heartRate)
                _ = await (first, second)
            case .retryAndEnqueue:
                async let first: Void = uploader.retryPendingUploads()
                async let second: Void = uploader.enqueue(heartRate)
                _ = await (first, second)
            }

            #expect(
                await waitUntil {
                    let drained = await uploader.getDLQStatistics().totalBatches == 0
                    let stopped = !(await uploader.isUploadLoopRunning)
                    return drained && stopped
                },
                "Round \(round): the queue never drained"
            )

            var expected = ["earlier", "hr-1", "hr-2"]
            if wakes == .twoEnqueues { expected.append("steps-1") }
            #expect(
                recorder.uploadedIds.sorted() == expected.sorted(),
                "Round \(round): uploads were \(recorder.uploads)"
            )
            #expect(recorder.maxInFlight == 1, "Round \(round): two upload loops ran at once")

            await uploader.dispose()
        }
    }
}
