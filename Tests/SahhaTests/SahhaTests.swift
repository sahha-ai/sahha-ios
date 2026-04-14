import Testing
import Foundation
import HealthKit  // For HealthKit mocks
@testable import Sahha  // Access internal SDK components

// MARK: - Mocks (Self-contained for testing; no SDK changes)
class MockHKHealthStore: HKHealthStore {
    var executedQueries: [HKObserverQuery] = []
    var stoppedQueries: [HKObserverQuery] = []
    var simulatedError: Error? = nil
    
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
    
    // Simulate a HealthKit update by calling the query's handler
    func simulateUpdate(for query: HKObserverQuery) {
        query.updateHandler?(query, {}, simulatedError)
    }
}

class MockAPIClient: APIClientProtocol {
    var shouldSucceed = true
    var simulatedResponse: APIResponse?
    var lastRequest: APIRequest?
    
    func send(_ request: APIRequest) async throws -> APIResponse {
        lastRequest = request
        if shouldSucceed {
            return simulatedResponse ?? APIResponse(Data(), HTTPURLResponse())
        } else {
            throw NSError(domain: "TestError", code: 500, userInfo: nil)
        }
    }
}

class MockNetworkMonitor: NetworkMonitor {
    private var _isConnected = true
    override var isConnected: Bool { _isConnected }
    
    func setConnected(_ connected: Bool) {
        _isConnected = connected
        // Simulate callback
        Task { await notifyStateChange(connected) }
    }
}

// MARK: - Tests
@Test("APIClient: GZIP compression matches expected format")
func testGZIPCompression() async throws {
    let client = APIClient(baseURL: URL(string: "https://example.com")!)
    let testData = "Test data for compression".data(using: .utf8)!
    
    // Compress
    let compressed = try client.compressGzip(data: testData)
    
    // Basic checks (header, footer, size)
    #expect(compressed.count < testData.count)  // Compression occurred
    #expect(compressed[0] == 0x1F)  // GZIP header ID1
    #expect(compressed[1] == 0x8B)  // GZIP header ID2
    
    // Decompress to verify (simulate server-side)
    let decompressed = try decompressGZIP(compressed)
    #expect(decompressed == testData)
}

// Helper for test (simulates server decompression)
private func decompressGZIP(_ data: Data) throws -> Data {
    let bufferSize = data.count * 2
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }
    
    let decompressedSize = data.withUnsafeBytes { sourceBuffer in
        compression_decode_buffer(
            buffer,
            bufferSize,
            sourceBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self),
            data.count,
            nil,
            COMPRESSION_ZLIB
        )
    }
    
    #expect(decompressedSize > 0)
    return Data(bytes: buffer, count: decompressedSize)
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

@Test("CircuitBreaker: Opens after failure threshold")
func testCircuitBreakerOpensAfterThreshold() async {
    let breaker = CircuitBreaker(failureThreshold: 3, recoveryTimeout: 0.1)
    for _ in 0..<3 { await breaker.recordFailure() }
    #expect(await breaker.shouldAllowRequest() == false)
    let (state, _) = await breaker.getState()
    #expect(state == .open)
}

@Test("CircuitBreaker: Recovers to half-open after timeout")
func testCircuitBreakerRecoversAfterTimeout() async throws {
    let breaker = CircuitBreaker(failureThreshold: 1, recoveryTimeout: 0.1)
    await breaker.recordFailure()
    try await Task.sleep(for: .seconds(0.2))
    #expect(await breaker.shouldAllowRequest() == true)
    let (state, _) = await breaker.getState()
    #expect(state == .halfOpen)
}

@Test("CircuitBreaker: Closes after successes in half-open")
func testCircuitBreakerClosesAfterSuccesses() async throws {
    let breaker = CircuitBreaker(failureThreshold: 1, recoveryTimeout: 0.1, halfOpenSuccessThreshold: 2)
    await breaker.recordFailure()
    try await Task.sleep(for: .seconds(0.2))  // Enter half-open
    await breaker.recordSuccess()
    await breaker.recordSuccess()
    let (state, _) = await breaker.getState()
    #expect(state == .closed)
}

@Test("NetworkMonitor: Initial state and monitoring")
func testNetworkMonitorInitialState() async {
    let monitor = NetworkMonitor()
    #expect(await monitor.isConnected == true)
    await monitor.startMonitoring()
    // Note: To test changes, use a mock or real network toggle
}

@Test("NetworkMonitor: Wait for connectivity timeout")
func testNetworkMonitorWaitForConnectivityTimeout() async throws {
    let monitor = MockNetworkMonitor()
    monitor.setConnected(false)
    
    do {
        try await monitor.waitForConnectivity(timeout: 0.1)
        #expect(Bool(false), "Should throw timeout")
    } catch {
        #expect(error is NetworkError)
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

@Test("UnifiedDeadLetterQueue: Cleanup exceeds max batches")
func testDeadLetterQueueCleanup() async throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let queue = UnifiedDeadLetterQueue<DataLogRequest>(baseDirectory: tempDir, maxStoredBatches: 2)

    for _ in 0..<4 {
        let chunk = UploadChunk<DataLogRequest>(requests: [], sizeInBytes: 0, priority: .normal)
        await queue.persistBatch(chunk)
        try await Task.sleep(for: .milliseconds(10))  // Ensure different timestamps
    }

    let count = await queue.getCount()
    #expect(count == 2)  // Oldest 2 removed

    try? FileManager.default.removeItem(at: tempDir)
}

@Test("SDK: Configuration succeeds")
func testSDKConfiguration() async throws {
    let settings = SahhaSettings(environment: .sandbox)  // Use test settings
    try await SahhaActor.shared.configure(with: settings)
    #expect(SahhaActor.shared.container != nil)
}

@Test("SDK: Authentication flow")
func testSDKAuthentication() async throws {
    // Assumes mocks or test credentials; replace with valid test values
    let authManager = try await SahhaActor.shared.authManager()
    try await authManager.authenticate(appId: "test-app-id", appSecret: "test-secret", externalId: "test-external-id")
    #expect(Sahha.isAuthenticated == true)
}

@Test("SDK: HealthKit observer receives notifications")
func testSDKHealthKitObserver() async throws {
    // Setup with mocks
    let mockHealthStore = MockHKHealthStore()
    let observerService = HealthKitObserverService(healthStore: mockHealthStore, /* inject other deps */)
    
    var handlerCalled = false
    try await observerService.startObservers(for: [.heartRate]) { _, _ in
        handlerCalled = true
    }
    
    // Simulate update
    let query = mockHealthStore.executedQueries.first!
    mockHealthStore.simulateUpdate(for: query)
    
    #expect(handlerCalled == true)
}

@Test("SDK: Circuit breaker opens after failures")
func testSDKDataUploadCircuitOpen() async throws {
    let breaker = CircuitBreaker(failureThreshold: 1)
    await breaker.recordFailure()

    // Circuit breaker should be open and reject requests
    #expect(await breaker.shouldAllowRequest() == false)
}

@Test("SDK: Offline data persistence via UnifiedDeadLetterQueue")
func testSDKOfflineRecovery() async throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let queue = UnifiedDeadLetterQueue<DataLogRequest>(baseDirectory: tempDir)

    let chunk = UploadChunk<DataLogRequest>(requests: [], sizeInBytes: 0, priority: .high)
    let id = await queue.persistBatch(chunk)
    #expect(id != nil)

    // Verify persisted
    let batches = await queue.loadAllBatches()
    #expect(batches.count == 1)

    // Simulate recovery: remove after upload
    await queue.removeBatch(withId: id!)
    let emptyBatches = await queue.loadAllBatches()
    #expect(emptyBatches.isEmpty)

    try? FileManager.default.removeItem(at: tempDir)
}

@Test func example() async throws {
    // Your existing test - keep or expand
}

@Test("DiagnosticReport: queues field replaces dataLogDLQ and tagDLQ in encoded payload")
func testDiagnosticReportQueuesEncoding() throws {
    let report = DiagnosticReport(
        timestamp: Date(timeIntervalSince1970: 1_000_000_000),
        sdkVersion: "1.0.0",
        deviceModel: "iPhone",
        system: "iOS",
        systemVersion: "17.0",
        appId: "com.sahha.test",
        enabledSensors: [],
        sensorStatuses: [:],
        observerStatuses: .init(
            sensorsChecked: [],
            sensorsReRegistered: [],
            failures: [:],
            lastCheckTimestamp: nil
        ),
        queues: .init(
            dataLog: .init(totalBatches: 2, totalItems: 10, failedBatches: 1, oldestBatchAge: 42),
            tag: .init(totalBatches: 3, totalItems: 15, failedBatches: 0, oldestBatchAge: nil)
        ),
        circuitBreakerState: "closed",
        circuitBreakerFailures: 0,
        isNetworkConnected: true
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
