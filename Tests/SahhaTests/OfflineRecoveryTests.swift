import Testing
import Foundation
@testable import Sahha

// MARK: - Test doubles & helpers

/// Captures what the upload service was asked to send, so tests can assert the
/// data was delivered exactly once (no duplicate submissions).
private actor UploadRecorder {
    private(set) var callCount = 0
    private(set) var uploadedIds: [String] = []

    func record(_ requests: [DataLogRequest]) {
        callCount += 1
        uploadedIds.append(contentsOf: requests.map(\.id))
    }
}

/// In-memory `UserDefaults` stand-in so `SentItemStore` never touches real
/// storage during tests.
private final class InMemoryStorage: UserDefaultsStorageProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var store: [String: Any] = [:]

    func set(_ value: Any?, forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        if let value { store[key] = value } else { store.removeValue(forKey: key) }
    }
    func get(forKey key: String) -> Any? {
        lock.lock(); defer { lock.unlock() }
        return store[key]
    }
    func removeObject(forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        store.removeValue(forKey: key)
    }
    func allKeys() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return Array(store.keys)
    }
}

private func makeDataLogRequest(id: String) -> DataLogRequest {
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

/// Exercises the real offline-recovery flow through `UnifiedUploader`: chunks that
/// can't be sent are persisted to the dead-letter queue, and are drained once the
/// app wakes or connectivity returns. Network state is driven deterministically via
/// the test-controlled `NetworkMonitor` (no live NWPathMonitor).
@Suite("Offline recovery")
struct OfflineRecoveryTests {

    private func makeUploader(
        tempDir: URL,
        monitor: NetworkMonitor,
        uploadService: @escaping @Sendable ([DataLogRequest]) async throws -> Void
    ) -> UnifiedUploader<DataLog, DataLogRequest> {
        UnifiedUploader<DataLog, DataLogRequest>(
            uploadService: uploadService,
            logger: NoopErrorLogger(),
            circuitBreaker: CircuitBreaker(),
            networkMonitor: monitor,
            persistentQueue: UnifiedDeadLetterQueue<DataLogRequest>(baseDirectory: tempDir),
            streamingProcessor: StreamingChunkProcessor<DataLog, DataLogRequest>(
                // Unused: these tests drive enqueue(_:) / retryPendingUploads() directly,
                // which bypass the item→request mapping path.
                mapItem: { _ in makeDataLogRequest(id: "unused") },
                assignPriority: { _ in .normal }
            ),
            sentStore: SentItemStore(storage: InMemoryStorage(), storageKey: "test.sent.\(UUID().uuidString)"),
            logLabel: "OfflineRecoveryTest"
        )
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

    @Test("A batch left in the DLQ is uploaded and removed when retried while online")
    func retryDrainsPendingBatch() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Simulate a batch persisted during a previous offline session.
        let seedQueue = UnifiedDeadLetterQueue<DataLogRequest>(baseDirectory: tempDir)
        let requests = [makeDataLogRequest(id: "a"), makeDataLogRequest(id: "b")]
        await seedQueue.persistBatch(UploadChunk(requests: requests, sizeInBytes: 100, priority: .high))

        let recorder = UploadRecorder()
        let uploader = makeUploader(tempDir: tempDir, monitor: NetworkMonitor(isConnected: true)) { reqs in
            await recorder.record(reqs)
        }

        // App wakes -> retry pending uploads.
        await uploader.retryPendingUploads()

        let drained = await waitUntil { await uploader.getDLQStatistics().totalBatches == 0 }
        #expect(drained)
        #expect(await recorder.callCount == 1)  // delivered exactly once
        #expect(await recorder.uploadedIds.sorted() == ["a", "b"])

        await uploader.dispose()
    }

    @Test("A chunk enqueued while offline is persisted, then uploaded once connectivity returns")
    func offlineThenReconnectUploads() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let monitor = NetworkMonitor(isConnected: false)  // start offline
        let recorder = UploadRecorder()
        let uploader = makeUploader(tempDir: tempDir, monitor: monitor) { reqs in
            await recorder.record(reqs)
        }

        let requests = [makeDataLogRequest(id: "x"), makeDataLogRequest(id: "y")]
        await uploader.enqueue(UploadChunk(requests: requests, sizeInBytes: 100, priority: .high))

        // Offline: the chunk is persisted and nothing is uploaded.
        let persisted = await waitUntil { await uploader.getDLQStatistics().totalBatches >= 1 }
        #expect(persisted)
        #expect(await recorder.callCount == 0)

        // Connectivity returns -> the parked upload loop resumes and drains the queue.
        await monitor.setConnectedForTesting(true)

        let drained = await waitUntil { await uploader.getDLQStatistics().totalBatches == 0 }
        #expect(drained)
        #expect(await recorder.callCount == 1)
        #expect(await recorder.uploadedIds.sorted() == ["x", "y"])

        await uploader.dispose()
    }
}
