import Testing
import Foundation
import HealthKit
@testable import Sahha

/// PRD #76 D13 prerequisite (issue #81): every store the deauthentication purge
/// wipes carries a `disposed` latch, checked by its write paths, so an async
/// flight that resolves after teardown cannot write state back behind the fresh
/// container's back. The token store established the pattern; these tests pin it
/// on the remaining stores. Each test also exercises the same write pre-dispose,
/// so "writes still succeed normally" is pinned by the same assertions.
@Suite("Disposed store write-back latches (D13 prerequisite)")
struct DisposedStoreLatchTests {

    @Test("Sent-item store: a post-dispose markSent leaves storage empty")
    func sentItemStoreLatch() async throws {
        let storage = InMemoryStorage()
        let store = SentItemStore(storage: storage, storageKey: "test.sent")

        await store.markSent(["a"])
        #expect(storage.get(forKey: "test.sent") != nil)
        #expect(await store.isSent("a"))

        await store.dispose()
        #expect(storage.get(forKey: "test.sent") == nil)

        // The uploader's in-flight success path calls markSent after teardown.
        await store.markSent(["b"])
        #expect(storage.get(forKey: "test.sent") == nil)
        #expect(await store.count() == 0)
        #expect(!(await store.isSent("b")))
    }

    @Test("Anchor store: a post-dispose save throws and leaves storage empty")
    func anchorStoreLatch() async throws {
        let storage = InMemoryStorage()
        let store = HealthKitAnchorStore(storage: storage)

        try await store.saveAnchor(HKQueryAnchor(fromValue: 7), forKey: "sleep")
        #expect(try await store.loadAnchor(forKey: "sleep") == HKQueryAnchor(fromValue: 7))

        await store.dispose()
        #expect(storage.allKeys().isEmpty)

        // A straggling anchored query saving its anchor after teardown must fail
        // (the throw stops its pagination loop) and must not touch storage.
        await #expect(throws: (any Error).self) {
            try await store.saveAnchor(HKQueryAnchor(fromValue: 8), forKey: "sleep")
        }
        #expect(storage.allKeys().isEmpty)
        #expect(try await store.loadAnchor(forKey: "sleep") == nil)
    }

    @Test("Anchor-date store: a post-dispose save leaves storage empty")
    func anchorDateStoreLatch() async throws {
        let storage = InMemoryStorage()
        let store = HealthKitAnchorDateStore(storage: storage)
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        await store.saveAnchorDate(date, forKey: "activity_summary")
        #expect(await store.loadAnchorDate(forKey: "activity_summary") == date)

        await store.dispose()
        #expect(storage.allKeys().isEmpty)

        await store.saveAnchorDate(date, forKey: "activity_summary")
        #expect(storage.allKeys().isEmpty)
        #expect(await store.loadAnchorDate(forKey: "activity_summary") == nil)
    }

    @Test("Sensor store: post-dispose writes throw and leave storage empty")
    func sensorStoreLatch() async throws {
        let storage = InMemoryStorage()
        let store = SensorStore(storage: storage, key: "test.sensors")

        try await store.setSensors([.sleep])
        #expect(storage.get(forKey: "test.sensors") != nil)

        await store.dispose()
        #expect(storage.get(forKey: "test.sensors") == nil)

        await #expect(throws: (any Error).self) {
            try await store.setSensors([.steps])
        }
        await #expect(throws: (any Error).self) {
            _ = try await store.replaceSensors([.steps])
        }
        #expect(storage.get(forKey: "test.sensors") == nil)

        // Statuses are memory-only, but a disposed store must stay inert too.
        await store.setSensorStatuses([.sleep: .enabled])
        #expect(await store.getSensorStatuses().isEmpty)
    }

    @Test("Sensor store: the lenient self-heal rewrite never fires on a disposed store")
    func sensorStoreSelfHealGate() async throws {
        let storage = InMemoryStorage()
        let store = SensorStore(storage: storage, key: "test.sensors")
        await store.dispose()

        // After teardown, whatever sits under this key belongs to someone else
        // (e.g. the fresh container's store). Seed a legacy-named set that the
        // lenient resolve would normally heal into canonical form.
        let legacyData = try JSONEncoder().encode(["energy_consumed"])
        storage.set(legacyData, forKey: "test.sensors")

        // Reads stay lenient — the legacy name still maps…
        #expect(try await store.getSensors() == [.energy_intake])
        // …but the read must not have rewritten the key to canonical form.
        #expect(storage.data(forKey: "test.sensors") == legacyData)
    }

    @Test("Demographic cache: a post-dispose cache write leaves the keychain empty")
    func demographicCacheLatch() async throws {
        let storage = MockKeychainStorage()
        let cache = DemographicCache(key: "test.demographic", storage: storage, logger: NoopErrorLogger())

        await cache.cacheDemographic(SahhaDemographic(gender: "female"))
        #expect(storage.storedKeys == ["test.demographic"])

        await cache.dispose()
        #expect(storage.storedKeys.isEmpty)

        // A demographic post resolving after deauth must not hand the departing
        // profile's demographic to the next profile.
        await cache.cacheDemographic(SahhaDemographic(gender: "female"))
        #expect(storage.storedKeys.isEmpty)
        #expect(await cache.getDemographic() == nil)
    }

    @Test("Device-info sync cache: a post-dispose cache write leaves storage empty")
    func deviceInfoSyncCacheLatch() async throws {
        let storage = InMemoryStorage()
        let cache = DeviceInfoSyncCache(key: "test.deviceinfo", storage: storage, logger: NoopErrorLogger())
        let info = DeviceInfo(
            sdkId: "ios", sdkVersion: "1.0", appId: "app", appVersion: "1.0",
            deviceId: "device", deviceType: "iPhone", deviceModel: "iPhone17,1",
            system: "iOS", systemVersion: "18.0", timeZone: "+00:00"
        )

        await cache.cacheDeviceInfo(info)
        #expect(storage.get(forKey: "test.deviceinfo") != nil)
        #expect(!(await cache.needsSync(comparedTo: info)))

        await cache.dispose()
        #expect(storage.get(forKey: "test.deviceinfo") == nil)

        await cache.cacheDeviceInfo(info)
        #expect(storage.get(forKey: "test.deviceinfo") == nil)
        #expect(await cache.needsSync(comparedTo: info))
    }
}

/// The unified uploader's own latch, plus the standalone bug issue #81 calls out:
/// dispose() cancels the upload loop mid-retry, and the cancelled `uploadChunk`
/// used to fall out of its retry loop into the max-retries tail — re-persisting
/// the batch into the just-purged dead-letter queue and posting a bogus
/// "Max retry attempts exceeded" error on every deauth with an upload in flight.
@Suite("Unified uploader disposed latch (D13 prerequisite)")
struct UnifiedUploaderDisposedLatchTests {

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

    private func makeUploader(
        tempDir: URL,
        logger: ErrorLoggerProtocol,
        uploadService: @escaping @Sendable ([DataLogRequest]) async throws -> Void
    ) -> UnifiedUploader<DataLog, DataLogRequest> {
        UnifiedUploader<DataLog, DataLogRequest>(
            uploadService: uploadService,
            logger: logger,
            circuitBreaker: CircuitBreaker(),
            networkMonitor: NetworkMonitor(isConnected: true),
            persistentQueue: UnifiedDeadLetterQueue<DataLogRequest>(baseDirectory: tempDir),
            streamingProcessor: StreamingChunkProcessor<DataLog, DataLogRequest>(
                // Unused: these tests drive enqueue(_:) directly.
                mapItem: { _ in
                    DataLogRequest(
                        id: "unused", logType: "activity", dataType: "steps",
                        value: 1, unit: "count", source: "test",
                        recordingMethod: "automatic", deviceType: "iPhone",
                        startDateTime: "2024-01-01T00:00:00.000",
                        endDateTime: "2024-01-01T00:00:00.000",
                        deviceId: "test-device"
                    )
                },
                assignPriority: { _ in .normal }
            ),
            sentStore: SentItemStore(storage: InMemoryStorage(), storageKey: "test.sent.\(UUID().uuidString)"),
            logLabel: "DisposedLatchTest"
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

    private func dlqFiles(in tempDir: URL) -> [URL] {
        let dir = tempDir.appendingPathComponent("PersistentQueue")
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }
    }

    @Test("Dispose mid-retry recreates no DLQ file and posts no bogus max-retries error")
    func disposeDuringFailingRetry() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let logger = RecordingErrorLogger()
        let uploader = makeUploader(tempDir: tempDir, logger: logger) { _ in
            throw URLError(.badServerResponse)
        }

        await uploader.enqueue(UploadChunk(
            requests: [makeDataLogRequest(id: "r1")], sizeInBytes: 10, priority: .high
        ))

        // Wait for the first genuine upload failure: enqueue has persisted the
        // batch (a pre-dispose write, proving writes still work) and the retry
        // loop is now parked in its backoff sleep.
        let failed = await waitUntil { logger.count >= 1 }
        #expect(failed)
        #expect(!dlqFiles(in: tempDir).isEmpty)

        // Deauthentication: dispose purges the queue and cancels the loop,
        // which interrupts the backoff sleep mid-retry.
        await uploader.dispose()

        // Give a regressed fall-through ample time to fire, then assert nothing
        // was written back and nothing bogus was posted.
        try await Task.sleep(nanoseconds: 500_000_000)
        #expect(dlqFiles(in: tempDir).isEmpty)
        #expect(await uploader.getDLQStatistics().totalBatches == 0)
        let posted = logger.drain().map { "\($0.error)" }
        #expect(!posted.contains { $0.contains("Max retry attempts exceeded") })
    }

    @Test("Enqueue after dispose persists nothing and starts no upload loop")
    func enqueueAfterDisposeIsInert() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let counter = UploadCallCounter()
        let uploader = makeUploader(tempDir: tempDir, logger: NoopErrorLogger()) { _ in
            await counter.increment()
        }

        await uploader.dispose()
        await uploader.enqueue(UploadChunk(
            requests: [makeDataLogRequest(id: "r1")], sizeInBytes: 10, priority: .high
        ))
        await uploader.retryPendingUploads()

        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(dlqFiles(in: tempDir).isEmpty)
        #expect(await uploader.getDLQStatistics().totalBatches == 0)
        #expect(await counter.count == 0)
    }
}

private actor UploadCallCounter {
    private(set) var count = 0
    func increment() { count += 1 }
}
