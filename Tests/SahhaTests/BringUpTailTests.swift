import Testing
import Foundation
import HealthKit

@testable import Sahha

// Coverage for the deterministic authenticated bring-up tail (PRD #76 D8).
//
// The dashboard's sensor panel used to depend on lifecycle listeners: the probe's
// foreground event does not fire on cold launch, and the resume event can fire
// before listeners register and be lost — so whether the first diagnostic report
// carried real statuses was a race. The bring-up tail now runs after observer
// arming on every authenticated path (launch, authenticate, deferred retry),
// posting the sensor store's latched anomaly and building + uploading a report;
// the report builder probes on demand when no statuses exist yet.
//
// Actor-level tests use the non-shared `SahhaActor` seam over doubles, so the
// suite stays parallel-safe; no lifecycle event is ever fired, which is the point.

// MARK: - Doubles

/// Records every request; plain sends succeed, typed sends fail (nothing in the
/// tail needs a decoded response — branches that do log and continue).
private final class RecordingAPIClient: APIClientProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [APIRequest] = []

    var requests: [APIRequest] {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }

    var diagnosticRequests: [APIRequest] {
        requests.filter { $0.endpoint == APIEndpoints.diagnostic }
    }

    func send(_ request: APIRequest) async throws {
        record(request)
    }

    func send<T: Decodable>(_ request: APIRequest) async throws -> T {
        record(request)
        throw SahhaError(message: "typed send is not scripted in RecordingAPIClient")
    }

    private func record(_ request: APIRequest) {
        lock.lock(); defer { lock.unlock() }
        recorded.append(request)
    }
}

/// Answers every sample query through one scripted closure.
private struct ScriptedSampleQueryService: HealthKitSampleQueryServiceProtocol {
    let script: @Sendable (HKSampleType) async throws -> [HKSample]

    func runSampleQuery(
        for sampleType: HKSampleType,
        predicate: NSPredicate?,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKSample] {
        try await script(sampleType)
    }
}

/// Stands in for the HealthKit manager during bring-up: arming reduces to the
/// store read that matters to the tail (it is what latches a store anomaly)
/// plus the observer-store bookkeeping a successful arm leaves behind, with no
/// live HealthKit dependency. `armsOnResume: false` simulates a resume whose
/// arming was dropped, so the tail health check has something to repair.
private final class StoreReadingHealthKitManager: HealthKitManagerProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private let sensorStore: SensorStoreProtocol
    private let observerStore: HealthKitObserverStoreProtocol
    private let armsOnResume: Bool
    private var _resumeForCalls: [Set<SahhaSensor>] = []

    /// Sets the health check asked to repair, in call order.
    var resumeForCalls: [Set<SahhaSensor>] {
        lock.lock(); defer { lock.unlock() }
        return _resumeForCalls
    }

    init(sensorStore: SensorStoreProtocol, observerStore: HealthKitObserverStoreProtocol, armsOnResume: Bool) {
        self.sensorStore = sensorStore
        self.observerStore = observerStore
        self.armsOnResume = armsOnResume
    }

    func enableSensors(_ sensors: Set<SahhaSensor>) async throws {}
    func resumeSensors() async {
        guard let sensors = try? await sensorStore.getSensors() else { return }
        guard armsOnResume else { return }
        await arm(sensors)
    }
    func resumeSensors(for sensors: Set<SahhaSensor>) async {
        recordResumeFor(sensors)
        await arm(sensors)
    }
    private func recordResumeFor(_ sensors: Set<SahhaSensor>) {
        lock.lock(); defer { lock.unlock() }
        _resumeForCalls.append(sensors)
    }
    private func arm(_ sensors: Set<SahhaSensor>) async {
        for sensor in sensors {
            guard let sampleType = sensor.hkSampleType else { continue }
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { _, _, _ in }
            await observerStore.replaceObserver(query, for: sensor, stoppingDisplaced: { _ in }, executing: { _ in })
            await observerStore.recordDeliveryEnabled(for: sensor)
        }
    }
    func querySensors() async -> PostSensorDataResult { PostSensorDataResult(sensorResults: []) }
    func getSensorStatus(_ sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus { .pending }
    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat] { [] }
    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaSample] { [] }
    func getDemographic() async throws -> SahhaDemographic { SahhaDemographic() }
    func postInsights() async {}
}

/// Auth manager whose token validity is fixed per test, so configure either
/// runs authenticated bring-up (launch path) or leaves it to an explicit
/// `startAuthenticatedServices()` (authenticate path).
private actor StubAuthManager: AuthManagerProtocol {
    private let hasValid: Bool

    init(hasValid: Bool) {
        self.hasValid = hasValid
    }

    func authenticate(appId: String, appSecret: String, externalId: String) async throws {}
    func authenticate(profileToken: String, refreshToken: String) async throws {}
    func getValidProfileToken() async throws -> String { "stub-token" }
    func refreshProfileToken(staleToken: String) async throws -> String { "stub-token" }
    func hasValidProfileToken() async -> Bool { hasValid }
}

private final class RecordingProbe: SensorProbeServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var runs = 0

    var runCount: Int {
        lock.lock(); defer { lock.unlock() }
        return runs
    }

    func runProbe() async {
        recordRun()
    }

    private func recordRun() {
        lock.lock(); defer { lock.unlock() }
        runs += 1
    }
}

// MARK: - Helpers

private func heartRateSample() -> HKQuantitySample {
    let type = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    let bpm = HKUnit.count().unitDivided(by: .minute())
    let date = Date().addingTimeInterval(-24 * 3600)
    return HKQuantitySample(type: type, quantity: HKQuantity(unit: bpm, doubleValue: 70), start: date, end: date)
}

private func seedSensors(_ storage: InMemoryStorage, rawValues: [String]) throws {
    storage.set(try JSONEncoder().encode(rawValues), forKey: StorageKeys.UserDefaults.sensors)
}

private func decodeReport(_ request: APIRequest) throws -> DiagnosticReport {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(DiagnosticReport.self, from: try #require(request.body))
}

/// A non-shared actor over the production graph with persistence, network,
/// health-store access, and auth swapped for the given doubles.
/// Hands the registrar-built manager stub back to the test, so assertions can
/// read what the tail health check asked it to repair.
private final class ManagerBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _manager: StoreReadingHealthKitManager?

    var manager: StoreReadingHealthKitManager? {
        lock.lock(); defer { lock.unlock() }
        return _manager
    }

    func set(_ manager: StoreReadingHealthKitManager) {
        lock.lock(); defer { lock.unlock() }
        _manager = manager
    }
}

private func makeActor(
    storage: InMemoryStorage,
    logger: RecordingErrorLogger,
    apiClient: RecordingAPIClient,
    hasValidToken: Bool,
    sampleQuery: ScriptedSampleQueryService,
    armsOnResume: Bool = true,
    managerBox: ManagerBox? = nil
) -> SahhaActor {
    SahhaActor(
        registrar: { container, settings in
            await SahhaActor.registerProductionDependencies(container: container, settings: settings)
            await container.register(UserDefaultsStorageProtocol.self) { _ in storage }
            await container.register(KeychainStorageProtocol.self) { _ in MockKeychainStorage() }
            await container.register(ErrorLoggerProtocol.self) { _ in logger }
            await container.register(APIClientProtocol.self) { _ in apiClient }
            await container.register(AuthManagerProtocol.self) { _ in StubAuthManager(hasValid: hasValidToken) }
            await container.register(HealthKitSampleQueryServiceProtocol.self) { _ in sampleQuery }
            await container.register(HealthKitManagerProtocol.self) { container in
                let manager = StoreReadingHealthKitManager(
                    sensorStore: try await container.resolve(SensorStoreProtocol.self),
                    observerStore: try await container.resolve(HealthKitObserverStoreProtocol.self),
                    armsOnResume: armsOnResume
                )
                managerBox?.set(manager)
                return manager
            }
        },
        lifecycleObserver: LifecycleObserverSpy()
    )
}

private let alwaysSample: ScriptedSampleQueryService = ScriptedSampleQueryService { _ in [heartRateSample()] }

// MARK: - Suite

@Suite("Authenticated bring-up tail")
struct BringUpTailTests {

    // MARK: Bring-up tail (actor level)

    @Test("A cold-launch bring-up uploads a report with real probed statuses, with no lifecycle event fired")
    func coldLaunchUploadsProbedReport() async throws {
        let storage = InMemoryStorage()
        try seedSensors(storage, rawValues: ["sleep"])
        let apiClient = RecordingAPIClient()
        let actor = makeActor(
            storage: storage,
            logger: RecordingErrorLogger(),
            apiClient: apiClient,
            hasValidToken: true,
            sampleQuery: alwaysSample
        )

        try await actor.configure(with: SahhaSettings(environment: .sandbox))

        let uploads = apiClient.diagnosticRequests
        #expect(uploads.count == 1)
        let report = try decodeReport(try #require(uploads.first))
        #expect(report.enabledSensors == ["sleep"])
        #expect(report.sensorStatuses == ["sleep": "enabled"])
    }

    @Test("The authenticate path runs the identical bring-up tail")
    func authenticatePathRunsTail() async throws {
        let storage = InMemoryStorage()
        try seedSensors(storage, rawValues: ["sleep"])
        let apiClient = RecordingAPIClient()
        let actor = makeActor(
            storage: storage,
            logger: RecordingErrorLogger(),
            apiClient: apiClient,
            hasValidToken: false,
            sampleQuery: alwaysSample
        )

        try await actor.configure(with: SahhaSettings(environment: .sandbox))
        #expect(apiClient.diagnosticRequests.isEmpty)

        try await actor.startAuthenticatedServices()

        let uploads = apiClient.diagnosticRequests
        #expect(uploads.count == 1)
        let report = try decodeReport(try #require(uploads.first))
        #expect(report.sensorStatuses == ["sleep": "enabled"])
    }

    @Test("The store anomaly latched during arming is posted exactly once, and the uploaded report is healed")
    func anomalyPostedExactlyOnceAtTail() async throws {
        let storage = InMemoryStorage()
        // A 1.3.7-era persisted set: the arming read heals it and latches the anomaly.
        try seedSensors(storage, rawValues: ["dietary_sugar", "sleep"])
        let logger = RecordingErrorLogger()
        let apiClient = RecordingAPIClient()
        let actor = makeActor(
            storage: storage,
            logger: logger,
            apiClient: apiClient,
            hasValidToken: true,
            sampleQuery: alwaysSample
        )

        try await actor.configure(with: SahhaSettings(environment: .sandbox))

        func anomalyPosts() -> [SahhaError] {
            logger.drain().compactMap { $0.error as? SahhaError }
                .filter { $0.message.contains("Sensor store healed legacy values") }
        }
        let firstPosts = anomalyPosts()
        #expect(firstPosts.count == 1)
        #expect(firstPosts.first?.message.contains("dietary_sugar") == true)

        let report = try decodeReport(try #require(apiClient.diagnosticRequests.first))
        #expect(report.enabledSensors == ["sleep", "sugar_intake"])

        // A second bring-up on the same session finds the latch already drained.
        try await actor.startAuthenticatedServices()
        #expect(anomalyPosts().isEmpty)
        #expect(apiClient.diagnosticRequests.count == 2)
    }

    // MARK: Bring-up-tail health check

    @Test("After a full resume, the bring-up-tail health check finds nothing missing")
    func tailHealthCheckIsNoOpAfterFullResume() async throws {
        let storage = InMemoryStorage()
        try seedSensors(storage, rawValues: ["sleep"])
        let logger = RecordingErrorLogger()
        let box = ManagerBox()
        let actor = makeActor(
            storage: storage,
            logger: logger,
            apiClient: RecordingAPIClient(),
            hasValidToken: true,
            sampleQuery: alwaysSample,
            managerBox: box
        )

        try await actor.configure(with: SahhaSettings(environment: .sandbox))

        // The check ran after arming: had it run before (or had arming not
        // registered sleep), it would have asked for a repair here.
        let manager = try #require(box.manager)
        #expect(manager.resumeForCalls.isEmpty)
        let aggregates = logger.drain().compactMap { ($0.error as? SahhaError)?.message }
            .filter { $0.contains("Observer re-registration failed") }
        #expect(aggregates.isEmpty)
    }

    @Test("The bring-up-tail health check repairs arming dropped during resume, with no lifecycle event fired")
    func tailHealthCheckRepairsDroppedArming() async throws {
        let storage = InMemoryStorage()
        try seedSensors(storage, rawValues: ["sleep"])
        let logger = RecordingErrorLogger()
        let box = ManagerBox()
        let actor = makeActor(
            storage: storage,
            logger: logger,
            apiClient: RecordingAPIClient(),
            hasValidToken: true,
            sampleQuery: alwaysSample,
            armsOnResume: false,   // resume leaves no observers behind
            managerBox: box
        )

        try await actor.configure(with: SahhaSettings(environment: .sandbox))

        // The tail check detected the missing observer and asked for a bounded
        // repair of exactly that sensor — no lifecycle event was ever fired.
        let manager = try #require(box.manager)
        #expect(manager.resumeForCalls == [[.sleep]])
        // The repair armed successfully, so nothing reached the aggregate post.
        let aggregates = logger.drain().compactMap { ($0.error as? SahhaError)?.message }
            .filter { $0.contains("Observer re-registration failed") }
        #expect(aggregates.isEmpty)
    }

    // MARK: Report builder probe-on-demand

    @Test("With statuses already present, the report carries them unchanged and the probe never runs")
    func existingStatusesSkipProbe() async throws {
        let storage = InMemoryStorage()
        try seedSensors(storage, rawValues: ["sleep"])
        let store = SensorStore(storage: storage)
        await store.setSensorStatuses([.sleep: .indeterminate])
        let probe = RecordingProbe()
        let builder = DiagnosticReportBuilder(
            sensorStore: store,
            sensorProbe: probe,
            dataLogUploader: NullDataLogUploader(),
            tagUploader: NullTagUploader(),
            storage: storage,
            logger: RecordingErrorLogger()
        )

        let report = await builder.buildReport()

        #expect(report.sensorStatuses == ["sleep": "indeterminate"])
        #expect(probe.runCount == 0)
    }

    @Test("With no statuses, the builder probes first and the report carries the probed statuses")
    func emptyStatusesProbeThenBuild() async throws {
        let storage = InMemoryStorage()
        try seedSensors(storage, rawValues: ["sleep"])
        let store = SensorStore(storage: storage)
        let logger = RecordingErrorLogger()
        let builder = DiagnosticReportBuilder(
            sensorStore: store,
            sensorProbe: SensorProbeService(
                sensorStore: store,
                sampleQueryService: alwaysSample,
                logger: logger
            ),
            dataLogUploader: NullDataLogUploader(),
            tagUploader: NullTagUploader(),
            storage: storage,
            logger: logger
        )

        let report = await builder.buildReport()

        #expect(report.sensorStatuses == ["sleep": "enabled"])
        #expect(logger.count == 0)
    }

    // MARK: Probe bounds

    @Test("With 100+ sensors and every probe hanging, the sweep returns at the overall cap without flooding statuses")
    func overallCapBoundsHangingSweep() async throws {
        let sampleBacked = SahhaSensor.allCases.filter { $0.hkSampleType != nil }
        try #require(sampleBacked.count >= 100)
        let storage = InMemoryStorage()
        try seedSensors(storage, rawValues: sampleBacked.map(\.rawValue))
        let store = SensorStore(storage: storage)
        let logger = RecordingErrorLogger()
        let probe = SensorProbeService(
            sensorStore: store,
            sampleQueryService: ScriptedSampleQueryService { _ in
                try await Task.sleep(nanoseconds: 3_600_000_000_000)
                return []
            },
            logger: logger,
            sensorTimeout: 0.15,
            overallTimeout: 0.5
        )

        let start = Date()
        await probe.runProbe()
        let elapsed = Date().timeIntervalSince(start)

        #expect(elapsed < 3)
        let statuses = await store.getSensorStatuses()
        // Only sensors actually probed before the cap carry a status; the
        // cancelled remainder must not be flood-marked `.indeterminate`.
        #expect(statuses.count <= 5)
        #expect(statuses.values.allSatisfy { $0 == .indeterminate })
        let posted = logger.drain()
        #expect(posted.count == 1)
        #expect(posted.first?.error is AsyncTimeoutError)
    }

    @Test("One hanging sensor times out alone; the other sensor still gets its real status")
    func perSensorTimeoutIsolatesHangingSensor() async throws {
        let storage = InMemoryStorage()
        try seedSensors(storage, rawValues: ["sleep", "heart_rate"])
        let store = SensorStore(storage: storage)
        let logger = RecordingErrorLogger()
        let probe = SensorProbeService(
            sensorStore: store,
            sampleQueryService: ScriptedSampleQueryService { sampleType in
                if sampleType.identifier == HKQuantityTypeIdentifier.heartRate.rawValue {
                    try await Task.sleep(nanoseconds: 3_600_000_000_000)
                }
                return [heartRateSample()]
            },
            logger: logger,
            sensorTimeout: 0.3,
            overallTimeout: 5
        )

        await probe.runProbe()

        let statuses = await store.getSensorStatuses()
        #expect(statuses == [.sleep: .enabled, .heart_rate: .indeterminate])
        // A per-sensor timeout is a status, not an error post.
        #expect(logger.count == 0)
    }

    @Test("Probe results merge into existing statuses rather than replacing them")
    func probeMergesIntoExistingStatuses() async throws {
        let storage = InMemoryStorage()
        try seedSensors(storage, rawValues: ["sleep"])
        let store = SensorStore(storage: storage)
        await store.setSensorStatuses([.steps: .indeterminate])
        let probe = SensorProbeService(
            sensorStore: store,
            sampleQueryService: alwaysSample,
            logger: RecordingErrorLogger()
        )

        await probe.runProbe()

        let statuses = await store.getSensorStatuses()
        #expect(statuses == [.steps: .indeterminate, .sleep: .enabled])
    }

    @Test("The production probe bounds are 5s per sensor within a 30s cap")
    func productionBoundsArePinned() {
        #expect(SensorProbeService.defaultSensorTimeout == 5)
        #expect(SensorProbeService.defaultOverallTimeout == 30)
    }
}
