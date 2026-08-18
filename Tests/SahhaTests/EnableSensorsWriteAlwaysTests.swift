import Testing
import Foundation
import HealthKit
@testable import Sahha

/// Coverage for the enableSensors write-always ordering (PRD #76, D4) and the
/// truthful status query (D5 refinement a): the requested set is persisted
/// unconditionally, guards run in the right order, teardown and arming failures
/// are posted independently instead of aborting the call, and a store failure in
/// getSensorStatus surfaces as an error rather than a success-shaped `.pending`.
@Suite("EnableSensorsWriteAlways")
struct EnableSensorsWriteAlwaysTests {

    // MARK: - enableSensors ordering

    @Test("A throwing store read still persists the new set, starts both coordinators, and is posted")
    func throwingStoreReadStillPersistsAndStartsBoth() async throws {
        let store = ScriptedSensorStore(readError: SahhaError(
            message: "store read fixture",
            file: "Sahha/StoreFixture.swift", function: "read()", line: 7
        ))
        let harness = Harness(store: store)

        try await harness.manager.enableSensors([.steps, .menstrual_period])

        // The write landed despite the failing read (the default replaceSensors
        // writes before rethrowing), and both sides still armed.
        #expect(await store.writtenSets == [[.steps, .menstrual_period]])
        #expect(harness.dataLog.startAttempts == [[.steps]])
        #expect(harness.tag.startAttempts == [[.menstrual_period]])
        let posted = harness.logger.drain().compactMap { $0.error as? SahhaError }
        #expect(posted.count == 1)
        #expect(posted.first?.message == "The sensor store failed while enabling sensors.")
        #expect((posted.first?.error as? SahhaError)?.message == "store read fixture")
    }

    @Test("Teardown failures are posted independently and never block the already-landed write")
    func teardownFailuresArePostedIndependently() async throws {
        let store = ScriptedSensorStore(initial: [.sleep, .menstrual_period])
        let harness = Harness(store: store)
        harness.dataLog.stopError = SahhaError(
            message: "data log stop fixture",
            file: "Sahha/DataLogStopFixture.swift", function: "stop()", line: 1
        )
        harness.tag.stopError = SahhaError(
            message: "tag stop fixture",
            file: "Sahha/TagStopFixture.swift", function: "stop()", line: 1
        )

        try await harness.manager.enableSensors([.steps])

        #expect(await store.sensors == [.steps])
        // Both stops were attempted: the data-log stop failure did not skip the tag stop.
        #expect(harness.dataLog.stopAttempts == [[.sleep]])
        #expect(harness.tag.stopAttempts == [[.menstrual_period]])
        let messages = harness.logger.drain().compactMap { ($0.error as? SahhaError)?.message }
        #expect(messages.sorted() == ["data log stop fixture", "tag stop fixture"])
        // Arming still ran after the failed teardown.
        #expect(harness.dataLog.startAttempts == [[.steps]])
    }

    @Test("The empty-set guard rejects before any write or teardown")
    func emptySetGuardRejectsBeforeWriteOrTeardown() async throws {
        let store = ScriptedSensorStore(initial: [.steps])
        let harness = Harness(store: store)

        do {
            try await harness.manager.enableSensors([])
            Issue.record("Expected the empty-set error")
        } catch {
            #expect(error.localizedDescription == "Sensor set cannot be empty.")
        }

        // Nothing was written, stopped, started, or posted; the persisted set is intact.
        #expect(await store.writtenSets.isEmpty)
        #expect(await store.sensors == [.steps])
        #expect(harness.dataLog.stopAttempts.isEmpty)
        #expect(harness.tag.stopAttempts.isEmpty)
        #expect(harness.dataLog.startAttempts.isEmpty)
        #expect(harness.logger.count == 0)
    }

    @Test("The zero-HealthKit-backed guard persists the set, skips teardown, posts, and still arms device-side sensors")
    func zeroHealthKitGuardSkipsTeardownAndPosts() async throws {
        let store = ScriptedSensorStore(initial: [.steps, .sleep])
        let harness = Harness(store: store)

        try await harness.manager.enableSensors([.device_lock])

        #expect(await store.sensors == [.device_lock])
        #expect(harness.dataLog.stopAttempts.isEmpty)
        #expect(harness.tag.stopAttempts.isEmpty)
        let messages = harness.logger.drain().compactMap { ($0.error as? SahhaError)?.message }
        #expect(messages.count == 1)
        #expect(messages.first?.contains("2 HealthKit-backed sensor(s)") == true)
        #expect(messages.first?.contains("HealthKit teardown was skipped") == true)
        // Device-side collection still starts — non-HealthKit sets stay a supported flow.
        #expect(harness.dataLog.startAttempts == [[.device_lock]])
    }

    @Test("Narrowing between HealthKit-backed sets tears down normally and posts nothing")
    func narrowingBetweenHealthKitBackedSetsIsUnaffected() async throws {
        let store = ScriptedSensorStore(initial: [.steps, .sleep])
        let harness = Harness(store: store)

        try await harness.manager.enableSensors([.steps])

        #expect(await store.sensors == [.steps])
        #expect(harness.dataLog.stopAttempts == [[.sleep]])
        #expect(harness.logger.count == 0)
    }

    @Test("An all-non-HealthKit set on a fresh install succeeds without a guard post")
    func freshInstallNonHealthKitSetPostsNothing() async throws {
        let harness = Harness(store: ScriptedSensorStore())

        try await harness.manager.enableSensors([.device_lock])

        #expect(await harness.store.sensors == [.device_lock])
        #expect(harness.dataLog.startAttempts == [[.device_lock]])
        #expect(harness.logger.count == 0)
    }

    // MARK: - Arming side isolation

    @Test("A data-log arming failure is posted and does not prevent tag-side arming")
    func dataLogArmingFailureStillArmsTags() async throws {
        let harness = Harness(store: ScriptedSensorStore())
        harness.dataLog.startError = SahhaError(
            message: "data log start fixture",
            file: "Sahha/DataLogStartFixture.swift", function: "start()", line: 1
        )

        try await harness.manager.enableSensors([.steps, .menstrual_period])

        #expect(harness.tag.startAttempts == [[.menstrual_period]])
        let messages = harness.logger.drain().compactMap { ($0.error as? SahhaError)?.message }
        #expect(messages == ["data log start fixture"])
        #expect(await harness.store.sensors == [.steps, .menstrual_period])
    }

    @Test("A tag arming failure is posted and does not affect data-log arming")
    func tagArmingFailureDoesNotAffectDataLog() async throws {
        let harness = Harness(store: ScriptedSensorStore())
        harness.tag.startError = SahhaError(
            message: "tag start fixture",
            file: "Sahha/TagStartFixture.swift", function: "start()", line: 1
        )

        try await harness.manager.enableSensors([.steps, .menstrual_period])

        #expect(harness.dataLog.startAttempts == [[.steps]])
        let messages = harness.logger.drain().compactMap { ($0.error as? SahhaError)?.message }
        #expect(messages == ["tag start fixture"])
    }

    // MARK: - Concurrency

    @Test("Concurrent enables persist exactly one of the requested sets")
    func concurrentEnablesPersistExactlyOneRequestedSet() async throws {
        let sensorStore = SensorStore(storage: InMemoryStorage())
        let harness = Harness(sensorStore: sensorStore)
        let requests: [Set<SahhaSensor>] = [
            [.steps], [.sleep], [.heart_rate], [.active_energy_burned], [.height], [.exercise],
        ]

        try await withThrowingTaskGroup(of: Void.self) { group in
            for request in requests {
                group.addTask { try await harness.manager.enableSensors(request) }
            }
            try await group.waitForAll()
        }

        let persisted = try await sensorStore.getSensors()
        #expect(requests.contains(persisted))
    }

    @Test("Concurrent replaces chain previous sets without loss or duplication")
    func concurrentReplacesChainPreviousSets() async throws {
        let store = SensorStore(storage: InMemoryStorage())
        let requests: [Set<SahhaSensor>] = SahhaSensor.allCases.prefix(16).map { [$0] }

        let returned = try await withThrowingTaskGroup(of: Set<SahhaSensor>.self) { group in
            for request in requests {
                group.addTask { try await store.replaceSensors(request) }
            }
            var collected: [Set<SahhaSensor>] = []
            for try await previous in group {
                collected.append(previous)
            }
            return collected
        }

        // Each write is captured as exactly one later call's previous set: the
        // returned sets are the initial empty set plus every request except the
        // final surviving one. A non-atomic read/write would double-capture.
        let final = try await store.getSensors()
        var expected = Set(requests.filter { $0 != final })
        expected.insert([])
        #expect(returned.count == requests.count)
        #expect(Set(returned) == expected)
        #expect(requests.contains(final))
    }

    // MARK: - Truthful sensor status (D5a)

    @Test("A poisoned persisted blob with granted permissions reports .enabled, not .pending")
    func poisonedBlobWithGrantedPermissionsReportsEnabled() async throws {
        // The incident's exact persisted state: a 1.3.7-era blob holding a renamed
        // raw value. The lenient store heals it, so status must reach .enabled —
        // before the rework this returned the success-shaped .pending forever.
        let storage = InMemoryStorage()
        storage.set(
            try JSONEncoder().encode(["steps", "energy_consumed"]),
            forKey: StorageKeys.UserDefaults.sensors
        )
        let harness = Harness(sensorStore: SensorStore(storage: storage))

        let status = try await harness.manager.getSensorStatus([.steps])

        #expect(status == .enabled)
    }

    @Test("A store failure makes getSensorStatus throw a posted error with a public-facing message")
    func storeFailureMakesStatusThrow() async throws {
        let store = ScriptedSensorStore(readError: SahhaError(
            message: "status store fixture",
            file: "Sahha/StatusStoreFixture.swift", function: "read()", line: 3
        ))
        let harness = Harness(store: store)

        do {
            _ = try await harness.manager.getSensorStatus([.steps])
            Issue.record("Expected the store failure to rethrow")
        } catch {
            // The facade delivers SahhaError.from(error).localizedDescription to the
            // public callback, so this is the non-nil string integrators receive.
            #expect(SahhaError.from(error).localizedDescription == "Sensor status could not be read from the sensor store.")
            #expect(((error as? SahhaError)?.error as? SahhaError)?.message == "status store fixture")
        }

        let posted = harness.logger.drain().compactMap { $0.error as? SahhaError }
        #expect(posted.map(\.message) == ["Sensor status could not be read from the sensor store."])
    }
}

// MARK: - Test doubles (self-contained for this suite)

/// A HealthKitManager over scripted persistence and coordinator doubles, with a
/// real permissions service (RecordingHealthStore auto-grants, and its status
/// defaults to .unnecessary) and a recording error logger.
private struct Harness {
    let store: ScriptedSensorStore
    let dataLog = ScriptedDataLogCoordinator()
    let tag = ScriptedTagCoordinator()
    let logger = RecordingErrorLogger()
    let manager: HealthKitManager

    init(store: ScriptedSensorStore = ScriptedSensorStore()) {
        self.store = store
        self.manager = Self.makeManager(sensorStore: store, dataLog: dataLog, tag: tag, logger: logger)
    }

    /// For tests that need the real SensorStore rather than the scripted double.
    init(sensorStore: SensorStoreProtocol) {
        self.store = ScriptedSensorStore()
        self.manager = Self.makeManager(sensorStore: sensorStore, dataLog: dataLog, tag: tag, logger: logger)
    }

    private static func makeManager(
        sensorStore: SensorStoreProtocol,
        dataLog: ScriptedDataLogCoordinator,
        tag: ScriptedTagCoordinator,
        logger: RecordingErrorLogger
    ) -> HealthKitManager {
        HealthKitManager(
            permissions: HealthKitPermissionsService(healthStore: RecordingHealthStore(), requestTimeout: 5),
            sensorStore: sensorStore,
            dataLogCoordinator: dataLog,
            tagCoordinator: tag,
            statCoordinator: StubStatCoordinator(),
            sampleCoordinator: StubSampleCoordinator(),
            demographicService: StubDemographicService(),
            activitySummaryUploader: StubActivitySummaryUploader(),
            logger: logger
        )
    }
}

/// Sensor store double with scriptable read/write failures. Does not implement
/// replaceSensors, so it also exercises the protocol's default write-always
/// composition over these primitives.
private actor ScriptedSensorStore: SensorStoreProtocol {
    private(set) var sensors: Set<SahhaSensor>
    private(set) var writtenSets: [Set<SahhaSensor>] = []
    private var statuses: [SahhaSensor: SahhaSensorStatus] = [:]
    private let readError: Error?
    private let writeError: Error?

    init(initial: Set<SahhaSensor> = [], readError: Error? = nil, writeError: Error? = nil) {
        self.sensors = initial
        self.readError = readError
        self.writeError = writeError
    }

    func setSensors(_ sensors: Set<SahhaSensor>) throws {
        if let writeError { throw writeError }
        writtenSets.append(sensors)
        self.sensors = sensors
    }

    func getSensors() throws -> Set<SahhaSensor> {
        if let readError { throw readError }
        return sensors
    }

    func hasSensor(_ sensor: SahhaSensor) -> Bool { sensors.contains(sensor) }
    func setSensorStatuses(_ statuses: [SahhaSensor: SahhaSensorStatus]) { self.statuses = statuses }
    func getSensorStatuses() -> [SahhaSensor: SahhaSensorStatus] { statuses }
}

private final class ScriptedDataLogCoordinator: HealthKitDataLogCoordinatorProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _startAttempts: [Set<SahhaSensor>] = []
    private var _stopAttempts: [Set<SahhaSensor>] = []
    private var _startError: Error?
    private var _stopError: Error?

    var startAttempts: [Set<SahhaSensor>] {
        lock.lock(); defer { lock.unlock() }
        return _startAttempts
    }
    var stopAttempts: [Set<SahhaSensor>] {
        lock.lock(); defer { lock.unlock() }
        return _stopAttempts
    }
    var startError: Error? {
        get { lock.lock(); defer { lock.unlock() }; return _startError }
        set { lock.lock(); defer { lock.unlock() }; _startError = newValue }
    }
    var stopError: Error? {
        get { lock.lock(); defer { lock.unlock() }; return _stopError }
        set { lock.lock(); defer { lock.unlock() }; _stopError = newValue }
    }

    func startDataLogCollection(for sensors: Set<SahhaSensor>) async throws {
        if let error = recordStart(sensors) { throw error }
    }

    func stopDataLogCollection(for sensors: Set<SahhaSensor>) async throws {
        if let error = recordStop(sensors) { throw error }
    }

    func querySensors(_ sensors: Set<SahhaSensor>) async -> [SensorQueryResult] { [] }

    private func recordStart(_ sensors: Set<SahhaSensor>) -> Error? {
        lock.lock(); defer { lock.unlock() }
        _startAttempts.append(sensors)
        return _startError
    }

    private func recordStop(_ sensors: Set<SahhaSensor>) -> Error? {
        lock.lock(); defer { lock.unlock() }
        _stopAttempts.append(sensors)
        return _stopError
    }
}

private final class ScriptedTagCoordinator: HealthKitTagCoordinatorProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _startAttempts: [Set<SahhaSensor>] = []
    private var _stopAttempts: [Set<SahhaSensor>] = []
    private var _startError: Error?
    private var _stopError: Error?

    var startAttempts: [Set<SahhaSensor>] {
        lock.lock(); defer { lock.unlock() }
        return _startAttempts
    }
    var stopAttempts: [Set<SahhaSensor>] {
        lock.lock(); defer { lock.unlock() }
        return _stopAttempts
    }
    var startError: Error? {
        get { lock.lock(); defer { lock.unlock() }; return _startError }
        set { lock.lock(); defer { lock.unlock() }; _startError = newValue }
    }
    var stopError: Error? {
        get { lock.lock(); defer { lock.unlock() }; return _stopError }
        set { lock.lock(); defer { lock.unlock() }; _stopError = newValue }
    }

    func startTagCollection(for sensors: Set<SahhaSensor>) async throws {
        if let error = recordStart(sensors) { throw error }
    }

    func stopTagCollection(for sensors: Set<SahhaSensor>) async throws {
        if let error = recordStop(sensors) { throw error }
    }

    func querySensors(_ sensors: Set<SahhaSensor>) async -> [SensorQueryResult] { [] }

    private func recordStart(_ sensors: Set<SahhaSensor>) -> Error? {
        lock.lock(); defer { lock.unlock() }
        _startAttempts.append(sensors)
        return _startError
    }

    private func recordStop(_ sensors: Set<SahhaSensor>) -> Error? {
        lock.lock(); defer { lock.unlock() }
        _stopAttempts.append(sensors)
        return _stopError
    }
}

private struct StubStatCoordinator: HealthKitSahhaStatCoordinatorProtocol {
    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat] { [] }
}

private struct StubSampleCoordinator: HealthKitSahhaSampleCoordinatorProtocol {
    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaSample] { [] }
}

private struct StubDemographicService: HealthKitDemographicServiceProtocol {
    func fetchGender() async throws -> HKBiologicalSex { .notSet }
    func fetchDateOfBirth() async throws -> Date? { nil }
}

private struct StubActivitySummaryUploader: HealthKitActivitySummaryUploaderProtocol {
    func postInsights() async {}
}
