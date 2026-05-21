import Testing
import Foundation
import HealthKit  // For HealthKit mocks
import Compression  // For verifying gzip round-trips
@testable import Sahha  // Access internal SDK components

// MARK: - Mocks (Self-contained for testing; no SDK changes)
final class MockHKHealthStore: HKHealthStore, @unchecked Sendable {
    var executedQueries: [HKObserverQuery] = []
    var stoppedQueries: [HKObserverQuery] = []

    override func execute(_ query: HKQuery) {
        if let observerQuery = query as? HKObserverQuery {
            executedQueries.append(observerQuery)
        }
    }

    override func stop(_ query: HKQuery) {
        if let observerQuery = query as? HKObserverQuery {
            stoppedQueries.append(observerQuery)
        }
    }
}

// MARK: - Tests
@Test("APIClient: GZIP compression emits valid framing and round-trips to the original bytes")
func testGZIPCompression() async throws {
    let client = APIClient(baseURL: URL(string: "https://example.com")!)
    // A mixed, compressible payload large enough that compression shrinks it
    // (tiny inputs can't, since gzip's 18-byte header/footer dominates).
    let testData = Data("Sahha gzip round-trip — ".utf8) + Data(repeating: 0x01, count: 2000)

    let compressed = try client.compressGzip(data: testData)

    #expect(compressed.count < testData.count)  // Compression occurred
    #expect(compressed[0] == 0x1F)  // GZIP header ID1
    #expect(compressed[1] == 0x8B)  // GZIP header ID2
    #expect(compressed[2] == 0x08)  // CM = DEFLATE

    // Strongest correctness check: inflating the gzip output must reproduce the
    // original bytes exactly. This exercises the hand-rolled CRC32/ISIZE footer
    // offsets too, not just the magic bytes.
    let restored = try #require(inflateGzip(compressed, decompressedSize: testData.count))
    #expect(restored == testData)
}

/// Inflates the SDK's gzip output by stripping the 10-byte gzip header and
/// 8-byte footer, then decoding the raw-DEFLATE body. Apple's COMPRESSION_ZLIB
/// is raw DEFLATE (RFC 1951), which is exactly the gzip payload between the frame.
private func inflateGzip(_ gzip: Data, decompressedSize: Int) -> Data? {
    let headerSize = 10
    let footerSize = 8
    guard gzip.count > headerSize + footerSize else { return nil }
    let deflateBody = gzip.subdata(in: headerSize ..< (gzip.count - footerSize))

    let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: decompressedSize)
    defer { dst.deallocate() }

    let written = deflateBody.withUnsafeBytes { src -> Int in
        guard let base = src.bindMemory(to: UInt8.self).baseAddress else { return 0 }
        return compression_decode_buffer(dst, decompressedSize, base, deflateBody.count, nil, COMPRESSION_ZLIB)
    }
    guard written > 0 else { return nil }
    return Data(bytes: dst, count: written)
}

@Test("APIClient: Compresses body if >1KB and sets header")
func testCompressBodyIfNeeded() async throws {
    let client = APIClient(baseURL: URL(string: "https://example.com")!)
    var request = URLRequest(url: URL(string: "https://example.com")!)
    let largeBody = Data(repeating: 0x01, count: 2000)  // >1KB
    request.httpBody = largeBody
    
    let compressedRequest = try client.compressBodyIfNeeded(request)
    #expect(compressedRequest != nil)
    #expect(compressedRequest!.httpBody!.count < largeBody.count)
    #expect(compressedRequest!.value(forHTTPHeaderField: "Content-Encoding") == "gzip")
}

@Test("NetworkMonitor: connectivity state gates upload attempts")
func testNetworkMonitorConnectivityGating() async {
    // A test-controlled monitor reports its seeded state and never starts a real
    // NWPathMonitor, so `shouldAttemptUpload()` reflects connectivity deterministically.
    let connected = NetworkMonitor(isConnected: true)
    #expect(await connected.isConnected == true)
    #expect(await connected.shouldAttemptUpload() == true)

    let disconnected = NetworkMonitor(isConnected: false)
    #expect(await disconnected.isConnected == false)
    #expect(await disconnected.shouldAttemptUpload() == false)
}

@Test("NetworkMonitor: Wait for connectivity timeout")
func testNetworkMonitorWaitForConnectivityTimeout() async throws {
    let monitor = NetworkMonitor(isConnected: false)

    do {
        try await monitor.waitForConnectivity(timeout: 0.1)
        #expect(Bool(false), "Should throw timeout")
    } catch {
        // Specifically the timeout case, not just any NetworkError.
        #expect((error as? NetworkError) == .timeout)
    }
}

@Test("UnifiedDeadLetterQueue: Persist and load batch")
func testDeadLetterQueuePersistAndLoad() async throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let queue = UnifiedDeadLetterQueue<DataLogRequest>(baseDirectory: tempDir)

    let testChunk = UploadChunk<DataLogRequest>(requests: [], sizeInBytes: 0, priority: .high)
    let id = await queue.persistBatch(testChunk)
    #expect(id != nil)

    let batches = await queue.loadAllBatches()
    #expect(batches.count == 1)

    await queue.removeBatch(withId: id!)
    let emptyBatches = await queue.loadAllBatches()
    #expect(emptyBatches.isEmpty)

    try? FileManager.default.removeItem(at: tempDir)
}

@Test("UnifiedDeadLetterQueue: Cleanup keeps only the newest batches when max is exceeded")
func testDeadLetterQueueCleanup() async throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let queue = UnifiedDeadLetterQueue<DataLogRequest>(baseDirectory: tempDir, maxStoredBatches: 2)

    // sizeInBytes acts as a per-batch marker so we can prove *which* batches survive.
    for marker in 1...4 {
        let chunk = UploadChunk<DataLogRequest>(requests: [], sizeInBytes: marker, priority: .normal)
        await queue.persistBatch(chunk)
        try await Task.sleep(nanoseconds: 50_000_000)  // Distinct creation timestamps for ordering
    }

    #expect(await queue.getCount() == 2)

    // The oldest two (markers 1, 2) are evicted; the newest two survive, oldest-first.
    let survivors = await queue.loadAllBatches().map(\.chunk.sizeInBytes)
    #expect(survivors == [3, 4])

    try? FileManager.default.removeItem(at: tempDir)
}

@Test("SDK: Configuration succeeds")
func testSDKConfiguration() async throws {
    let settings = SahhaSettings(environment: .sandbox)  // Use test settings
    try await SahhaActor.shared.configure(with: settings)

    // requireConfig() throws unless the DI container was built; a clean return
    // (and the round-tripped environment) proves configuration completed.
    let (_, resolvedSettings) = try await SahhaActor.shared.requireConfig()
    #expect(resolvedSettings.environment == .sandbox)
}

@Test("SDK: Authentication rejects empty credentials before any network call")
func testSDKAuthentication() async throws {
    try await SahhaActor.shared.configure(with: SahhaSettings(environment: .sandbox))
    let authManager = try await SahhaActor.shared.authManager()

    // Empty appId is rejected by validation before the auth service is contacted,
    // so this exercises real behavior without depending on the network.
    await #expect(throws: SahhaError.self) {
        try await authManager.authenticate(appId: "", appSecret: "test-secret", externalId: "test-external-id")
    }
}

@Test("SDK: HealthKit observer service registers an observer query")
func testSDKHealthKitObserver() async throws {
    let mockHealthStore = MockHKHealthStore()
    let observerStore = MockHealthKitObserverStore()
    let observerService = HealthKitObserverService(
        healthStore: mockHealthStore,
        observerStore: observerStore,
        logger: NoopErrorLogger()
    )

    // HKObserverQuery has no externally callable update handler, so we verify the
    // service registers and executes an observer rather than simulating delivery.
    try await observerService.startObservers(for: [.heart_rate]) { _, _ in }

    #expect(mockHealthStore.executedQueries.count == 1)
    let keys = await observerStore.getRegisteredKeys()
    #expect(keys.contains(SahhaSensor.heart_rate.rawValue))
}

@Test("DiagnosticReport: queues field replaces dataLogDLQ and tagDLQ in encoded payload")
func testDiagnosticReportQueuesEncoding() throws {
    let report = DiagnosticReport(
        timestamp: Date(timeIntervalSince1970: 1_000_000_000),
        enabledSensors: [],
        sensorStatuses: [:],
        queues: .init(
            dataLog: .init(totalBatches: 2, totalItems: 10, failedBatches: 1, oldestBatchAge: 42),
            tag: .init(totalBatches: 3, totalItems: 15, failedBatches: 0, oldestBatchAge: nil)
        )
    )

    let data = try JSONEncoder().encode(report)
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

    // New `queues` key present; old DLQ top-level keys absent.
    let topLevelKeys = Set(json.keys)
    #expect(topLevelKeys.contains("queues"))
    #expect(topLevelKeys.contains("dataLogDLQ") == false)
    #expect(topLevelKeys.contains("tagDLQ") == false)

    // queues.dataLog contains all expected snapshot fields with values intact.
    let queues = json["queues"] as! [String: Any]
    let dataLog = queues["dataLog"] as! [String: Any]
    #expect(dataLog["totalBatches"] as? Int == 2)
    #expect(dataLog["totalItems"] as? Int == 10)
    #expect(dataLog["failedBatches"] as? Int == 1)
    #expect(dataLog["oldestBatchAge"] as? Double == 42)

    // queues.tag contains all expected snapshot fields; nil oldestBatchAge is omitted.
    let tag = queues["tag"] as! [String: Any]
    #expect(tag["totalBatches"] as? Int == 3)
    #expect(tag["totalItems"] as? Int == 15)
    #expect(tag["failedBatches"] as? Int == 0)
    #expect(Set(tag.keys).contains("oldestBatchAge") == false)
}

@Test("DiagnosticReport: observerStatuses is absent from encoded payload")
func testDiagnosticReportOmitsObserverStatuses() throws {
    let report = DiagnosticReport(
        timestamp: Date(timeIntervalSince1970: 1_000_000_000),
        enabledSensors: [],
        sensorStatuses: [:],
        queues: .init(
            dataLog: .init(totalBatches: 0, totalItems: 0, failedBatches: 0, oldestBatchAge: nil),
            tag: .init(totalBatches: 0, totalItems: 0, failedBatches: 0, oldestBatchAge: nil)
        )
    )

    let data = try JSONEncoder().encode(report)
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

    #expect(Set(json.keys).contains("observerStatuses") == false)
}

@Test("DiagnosticReport: circuit breaker and network connectivity fields are absent from encoded payload")
func testDiagnosticReportOmitsTransientStateFields() throws {
    let report = DiagnosticReport(
        timestamp: Date(timeIntervalSince1970: 1_000_000_000),
        enabledSensors: [],
        sensorStatuses: [:],
        queues: .init(
            dataLog: .init(totalBatches: 0, totalItems: 0, failedBatches: 0, oldestBatchAge: nil),
            tag: .init(totalBatches: 0, totalItems: 0, failedBatches: 0, oldestBatchAge: nil)
        )
    )

    let data = try JSONEncoder().encode(report)
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

    let topLevelKeys = Set(json.keys)
    #expect(topLevelKeys.contains("circuitBreakerState") == false)
    #expect(topLevelKeys.contains("circuitBreakerFailures") == false)
    #expect(topLevelKeys.contains("isNetworkConnected") == false)
}

@Test("DiagnosticReport: device identity fields are absent from encoded payload")
func testDiagnosticReportOmitsDeviceIdentityFields() throws {
    let report = DiagnosticReport(
        timestamp: Date(timeIntervalSince1970: 1_000_000_000),
        enabledSensors: [],
        sensorStatuses: [:],
        queues: .init(
            dataLog: .init(totalBatches: 0, totalItems: 0, failedBatches: 0, oldestBatchAge: nil),
            tag: .init(totalBatches: 0, totalItems: 0, failedBatches: 0, oldestBatchAge: nil)
        )
    )

    let data = try JSONEncoder().encode(report)
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

    // Device identity flows via DeviceInfoSyncService → v1/profile/deviceInformation,
    // not through the diagnostic payload.
    let topLevelKeys = Set(json.keys)
    #expect(topLevelKeys.contains("sdkVersion") == false)
    #expect(topLevelKeys.contains("deviceModel") == false)
    #expect(topLevelKeys.contains("system") == false)
    #expect(topLevelKeys.contains("systemVersion") == false)
    #expect(topLevelKeys.contains("appId") == false)
}

@Test("DiagnosticReportBuilder: backfill marks enabled-but-unprobed sensors as .pending")
func testBackfillMarksMissingStatusesAsPending() throws {
    let enabled: Set<SahhaSensor> = [.heart_rate, .steps]
    let partial: [SahhaSensor: SahhaSensorStatus] = [.heart_rate: .enabled]

    let result = DiagnosticReportBuilder.backfillStatuses(enabled: enabled, statuses: partial)

    #expect(result.count == 2)
    #expect(result[.heart_rate] == .enabled)   // preserved
    #expect(result[.steps] == .pending)        // backfilled
}

@Test("DiagnosticReportBuilder: backfill yields empty map when enabled set is empty")
func testBackfillEmptyEnabledGivesEmptyMap() throws {
    let result = DiagnosticReportBuilder.backfillStatuses(enabled: [], statuses: [:])

    #expect(result.isEmpty)
}

@Test("DiagnosticReportBuilder: backfill preserves existing non-pending statuses")
func testBackfillPreservesExistingStatuses() throws {
    let enabled: Set<SahhaSensor> = [.heart_rate, .steps, .sleep]
    let existing: [SahhaSensor: SahhaSensorStatus] = [
        .heart_rate: .enabled,
        .steps: .disabled,
        .sleep: .unavailable,
    ]

    let result = DiagnosticReportBuilder.backfillStatuses(enabled: enabled, statuses: existing)

    #expect(result[.heart_rate] == .enabled)
    #expect(result[.steps] == .disabled)
    #expect(result[.sleep] == .unavailable)
    #expect(result.count == 3)   // no spurious entries
}

// MARK: - SensorHealthCheckLifecycleListener mocks

actor MockSensorStoreForHealthCheck: SensorStoreProtocol {
    private var sensors: Set<SahhaSensor> = []
    private var statuses: [SahhaSensor: SahhaSensorStatus] = [:]

    func setSensors(_ sensors: Set<SahhaSensor>) throws { self.sensors = sensors }
    func getSensors() throws -> Set<SahhaSensor> { sensors }
    func hasSensor(_ sensor: SahhaSensor) -> Bool { sensors.contains(sensor) }
    func setSensorStatuses(_ statuses: [SahhaSensor: SahhaSensorStatus]) { self.statuses = statuses }
    func getSensorStatuses() -> [SahhaSensor: SahhaSensorStatus] { statuses }
}

actor MockHealthKitObserverStore: HealthKitObserverStoreProtocol {
    private var registeredKeys: Set<String> = []

    /// Test helper: register a key without needing a real HKObserverQuery.
    func markRegistered(_ key: String) { registeredKeys.insert(key) }

    func addObserver(_ observer: HKObserverQuery, forKey key: String) { registeredKeys.insert(key) }
    func removeObserver(forKey key: String) -> HKObserverQuery? {
        registeredKeys.remove(key)
        return nil
    }
    func removeAllObservers() -> [HKObserverQuery] {
        registeredKeys.removeAll()
        return []
    }
    func getRegisteredKeys() -> Set<String> { registeredKeys }
}

final class MockHealthKitManager: HealthKitManagerProtocol, @unchecked Sendable {
    private let observerStore: MockHealthKitObserverStore
    private let sensorsToRegister: Set<SahhaSensor>

    /// Records invocations so tests can assert `resumeSensors()` was called.
    private(set) var resumeSensorsCallCount = 0

    init(observerStore: MockHealthKitObserverStore, sensorsToRegister: Set<SahhaSensor>) {
        self.observerStore = observerStore
        self.sensorsToRegister = sensorsToRegister
    }

    func resumeSensors() async {
        resumeSensorsCallCount += 1
        for sensor in sensorsToRegister {
            await observerStore.markRegistered(sensor.rawValue)
        }
    }

    // Unused by these tests — no-op conformance.
    func enableSensors(_ sensors: Set<SahhaSensor>) async throws {}
    func querySensors() async -> PostSensorDataResult { PostSensorDataResult(sensorResults: []) }
    func getSensorStatus(_ sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus { .pending }
    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat] { [] }
    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaSample] { [] }
    func getDemographic() async throws -> SahhaDemographic { SahhaDemographic() }
    func postInsights() async {}
}

final class NoopErrorLogger: ErrorLoggerProtocol, @unchecked Sendable {
    func postError(_ error: Error, file: StaticString, function: StaticString, line: UInt) {}
}

@Test("SensorHealthCheckLifecycleListener: re-registers missing observers on lifecycle event")
func testHealthCheckListenerRegistersMissingObservers() async throws {
    let sensorStore = MockSensorStoreForHealthCheck()
    try await sensorStore.setSensors([.heart_rate])

    let observerStore = MockHealthKitObserverStore()   // starts empty — observer is "missing"
    let healthKitManager = MockHealthKitManager(
        observerStore: observerStore,
        sensorsToRegister: [.heart_rate]   // resumeSensors will re-register it
    )

    let listener = SensorHealthCheckLifecycleListener(
        sensorStore: sensorStore,
        observerStore: observerStore,
        healthKitManager: healthKitManager,
        logger: NoopErrorLogger()
    )

    await listener.handleLifecycleEvent(.app_foreground)

    // HealthKitManager.resumeSensors() was invoked exactly once.
    #expect(healthKitManager.resumeSensorsCallCount == 1)

    // The missing observer is now registered in the store.
    let keys = await observerStore.getRegisteredKeys()
    #expect(keys.contains(SahhaSensor.heart_rate.rawValue))

    // The listener's latest result reflects the re-registration.
    let result = await listener.getLatestResult()
    #expect(result?.sensorsReRegistered.contains(.heart_rate) == true)
    #expect(result?.failures.isEmpty == true)
}
