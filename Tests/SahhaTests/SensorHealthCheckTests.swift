import Testing
import Foundation
import HealthKit
@testable import Sahha

// Coverage for the redesigned sensor health check (PRD #76 D11): bounded
// set-scoped re-arm with side isolation, single-flight, per-sensor background
// delivery with lone delivery repair, and the observer store's atomic replace
// (which makes orphaned observer queries impossible rather than merely rare).

// MARK: - Doubles

/// Records the set-scoped resumes the check requests; arming behavior is
/// scripted per test.
private final class RecordingResumeManager: HealthKitManagerProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _resumeForCalls: [Set<SahhaSensor>] = []
    private let onResumeFor: @Sendable (Set<SahhaSensor>) async -> Void

    init(onResumeFor: @escaping @Sendable (Set<SahhaSensor>) async -> Void = { _ in }) {
        self.onResumeFor = onResumeFor
    }

    var resumeForCalls: [Set<SahhaSensor>] {
        lock.lock(); defer { lock.unlock() }
        return _resumeForCalls
    }

    func resumeSensors(for sensors: Set<SahhaSensor>) async {
        record(sensors)
        await onResumeFor(sensors)
    }

    private func record(_ sensors: Set<SahhaSensor>) {
        lock.lock(); defer { lock.unlock() }
        _resumeForCalls.append(sensors)
    }

    func resumeSensors() async {}
    func enableSensors(_ sensors: Set<SahhaSensor>) async throws {}
    func querySensors() async -> PostSensorDataResult { PostSensorDataResult(sensorResults: []) }
    func getSensorStatus(_ sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus { .pending }
    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat] { [] }
    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaSample] { [] }
    func getDemographic() async throws -> SahhaDemographic { SahhaDemographic() }
    func postInsights() async {}
}

/// Records delivery and observer calls; delivery behavior is scripted per test.
private final class RecordingObserverService: HealthKitObserverServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _enableDeliveryCalls: [Set<SahhaSensor>] = []
    private var _startObserverCalls: [Set<SahhaSensor>] = []
    private let onEnableDelivery: @Sendable (Set<SahhaSensor>) async throws -> Void

    init(onEnableDelivery: @escaping @Sendable (Set<SahhaSensor>) async throws -> Void = { _ in }) {
        self.onEnableDelivery = onEnableDelivery
    }

    var enableDeliveryCalls: [Set<SahhaSensor>] {
        lock.lock(); defer { lock.unlock() }
        return _enableDeliveryCalls
    }

    var startObserverCalls: [Set<SahhaSensor>] {
        lock.lock(); defer { lock.unlock() }
        return _startObserverCalls
    }

    func startObservers(for sensors: Set<SahhaSensor>, handler: @escaping HealthKitObserverHandler) async throws {
        recordStart(sensors)
    }

    private func recordStart(_ sensors: Set<SahhaSensor>) {
        lock.lock(); defer { lock.unlock() }
        _startObserverCalls.append(sensors)
    }

    func enableBackgroundDelivery(for sensors: Set<SahhaSensor>) async throws {
        recordEnable(sensors)
        try await onEnableDelivery(sensors)
    }

    private func recordEnable(_ sensors: Set<SahhaSensor>) {
        lock.lock(); defer { lock.unlock() }
        _enableDeliveryCalls.append(sensors)
    }

    func stopObservers(for sensors: Set<SahhaSensor>) async throws {}
    func disableBackgroundDelivery(for sensors: Set<SahhaSensor>) async throws {}
    func dispose() async {}
}

/// Coordinators that record their start calls and leave the same observer-store
/// bookkeeping a successful real arm would.
private actor ArmingDataLogCoordinator: HealthKitDataLogCoordinatorProtocol {
    private let observerStore: HealthKitObserverStoreProtocol
    private(set) var startCalls: [Set<SahhaSensor>] = []

    init(observerStore: HealthKitObserverStoreProtocol) {
        self.observerStore = observerStore
    }

    func startDataLogCollection(for sensors: Set<SahhaSensor>) async throws {
        startCalls.append(sensors)
        await armIntoStore(observerStore, sensors)
    }
    func stopDataLogCollection(for sensors: Set<SahhaSensor>) async throws {}
    func querySensors(_ sensors: Set<SahhaSensor>) async -> [SensorQueryResult] { [] }
}

private actor ArmingTagCoordinator: HealthKitTagCoordinatorProtocol {
    private let observerStore: HealthKitObserverStoreProtocol
    private(set) var startCalls: [Set<SahhaSensor>] = []

    init(observerStore: HealthKitObserverStoreProtocol) {
        self.observerStore = observerStore
    }

    func startTagCollection(for sensors: Set<SahhaSensor>) async throws {
        startCalls.append(sensors)
        await armIntoStore(observerStore, sensors)
    }
    func stopTagCollection(for sensors: Set<SahhaSensor>) async throws {}
    func querySensors(_ sensors: Set<SahhaSensor>) async -> [SensorQueryResult] { [] }
}

private actor ThrowingDataLogCoordinator: HealthKitDataLogCoordinatorProtocol {
    private let error: SahhaError
    init(error: SahhaError) { self.error = error }

    func startDataLogCollection(for sensors: Set<SahhaSensor>) async throws { throw error }
    func stopDataLogCollection(for sensors: Set<SahhaSensor>) async throws { throw error }
    func querySensors(_ sensors: Set<SahhaSensor>) async -> [SensorQueryResult] { [] }
}

private actor ThrowingTagCoordinator: HealthKitTagCoordinatorProtocol {
    private let error: SahhaError
    init(error: SahhaError) { self.error = error }

    func startTagCollection(for sensors: Set<SahhaSensor>) async throws { throw error }
    func stopTagCollection(for sensors: Set<SahhaSensor>) async throws { throw error }
    func querySensors(_ sensors: Set<SahhaSensor>) async -> [SensorQueryResult] { [] }
}

private struct InertStatCoordinator: HealthKitSahhaStatCoordinatorProtocol {
    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat] { [] }
}

private struct InertSampleCoordinator: HealthKitSahhaSampleCoordinatorProtocol {
    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaSample] { [] }
}

private struct InertDemographicService: HealthKitDemographicServiceProtocol {
    func fetchGender() async throws -> HKBiologicalSex { .notSet }
    func fetchDateOfBirth() async throws -> Date? { nil }
}

private struct InertActivitySummaryUploader: HealthKitActivitySummaryUploaderProtocol {
    func postInsights() async {}
}

/// Holds concurrent check passes inside the manager until the test releases them.
private actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func waitUntilOpen() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        for waiter in waiters { waiter.resume() }
        waiters.removeAll()
    }
}

/// Thread-safe recorder for the queries the store's replace closures touch.
private final class QueryRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _executed: [HKObserverQuery] = []
    private var _stopped: [HKObserverQuery] = []

    var executed: [HKObserverQuery] {
        lock.lock(); defer { lock.unlock() }
        return _executed
    }
    var stopped: [HKObserverQuery] {
        lock.lock(); defer { lock.unlock() }
        return _stopped
    }
    func recordExecuted(_ query: HKObserverQuery) {
        lock.lock(); defer { lock.unlock() }
        _executed.append(query)
    }
    func recordStopped(_ query: HKObserverQuery) {
        lock.lock(); defer { lock.unlock() }
        _stopped.append(query)
    }
}

// MARK: - Helpers

private func observerQuery(for sensor: SahhaSensor) -> HKObserverQuery {
    HKObserverQuery(sampleType: sensor.hkSampleType!, predicate: nil) { _, _, _ in }
}

/// Leaves the bookkeeping of a fully successful arm: an executing observer and
/// a delivery record.
private func armIntoStore(_ store: HealthKitObserverStoreProtocol, _ sensors: Set<SahhaSensor>) async {
    for sensor in sensors where sensor.hkSampleType != nil {
        await store.replaceObserver(observerQuery(for: sensor), for: sensor, stoppingDisplaced: { _ in }, executing: { _ in })
        await store.recordDeliveryEnabled(for: sensor)
    }
}

private func makeCheckService(
    sensorStore: SensorStoreProtocol,
    observerStore: HealthKitObserverStoreProtocol,
    healthKitManager: HealthKitManagerProtocol,
    observerService: HealthKitObserverServiceProtocol = RecordingObserverService(),
    logger: ErrorLoggerProtocol
) -> SensorHealthCheckService {
    SensorHealthCheckService(
        sensorStore: sensorStore,
        observerStore: observerStore,
        healthKitManager: healthKitManager,
        observerService: observerService,
        logger: logger
    )
}

private func makeManager(
    sensorStore: SensorStoreProtocol,
    dataLogCoordinator: HealthKitDataLogCoordinatorProtocol,
    tagCoordinator: HealthKitTagCoordinatorProtocol,
    logger: ErrorLoggerProtocol
) -> HealthKitManager {
    HealthKitManager(
        permissions: HealthKitPermissionsService(healthStore: RecordingHealthStore(), requestTimeout: 5),
        sensorStore: sensorStore,
        dataLogCoordinator: dataLogCoordinator,
        tagCoordinator: tagCoordinator,
        statCoordinator: InertStatCoordinator(),
        sampleCoordinator: InertSampleCoordinator(),
        demographicService: InertDemographicService(),
        activitySummaryUploader: InertActivitySummaryUploader(),
        logger: logger
    )
}

// MARK: - Suite

@Suite("Sensor health check (D11)")
struct SensorHealthCheckTests {

    // MARK: Bounded detection and repair

    @Test("A healthy check is a no-op: nothing re-armed, nothing posted")
    func healthyCheckIsNoOp() async throws {
        let sensorStore = MockSensorStoreForHealthCheck()
        try await sensorStore.setSensors([.sleep, .heart_rate])
        let observerStore = HealthKitObserverStore()
        await armIntoStore(observerStore, [.sleep, .heart_rate])
        let manager = RecordingResumeManager()
        let observerService = RecordingObserverService()
        let logger = RecordingErrorLogger()
        let service = makeCheckService(
            sensorStore: sensorStore,
            observerStore: observerStore,
            healthKitManager: manager,
            observerService: observerService,
            logger: logger
        )

        let result = await service.runHealthCheck()

        #expect(result.allHealthy)
        #expect(result.sensorsChecked == [.sleep, .heart_rate])
        #expect(manager.resumeForCalls.isEmpty)
        #expect(observerService.enableDeliveryCalls.isEmpty)
        #expect(logger.count == 0)
    }

    @Test("Only the missing sensors are re-armed, not the whole enabled set")
    func onlyMissingSensorsAreReArmed() async throws {
        let sensorStore = MockSensorStoreForHealthCheck()
        try await sensorStore.setSensors([.sleep, .heart_rate])
        let observerStore = HealthKitObserverStore()
        await armIntoStore(observerStore, [.sleep])   // heart_rate is missing
        let manager = RecordingResumeManager(onResumeFor: { sensors in
            await armIntoStore(observerStore, sensors)
        })
        let logger = RecordingErrorLogger()
        let service = makeCheckService(
            sensorStore: sensorStore,
            observerStore: observerStore,
            healthKitManager: manager,
            logger: logger
        )

        let result = await service.runHealthCheck()

        #expect(manager.resumeForCalls == [[.heart_rate]])
        #expect(result.sensorsReRegistered == [.heart_rate])
        #expect(result.failures.isEmpty)
        #expect(logger.count == 0)
    }

    @Test("A sensor missing only its delivery gets the delivery call alone — never a second observer query")
    func deliveryOnlyRepairSkipsObserverQuery() async throws {
        let sensorStore = MockSensorStoreForHealthCheck()
        try await sensorStore.setSensors([.sleep])
        let observerStore = HealthKitObserverStore()
        // Observer registered, delivery record absent — the delivery-only gap.
        await observerStore.replaceObserver(observerQuery(for: .sleep), for: .sleep, stoppingDisplaced: { _ in }, executing: { _ in })
        let manager = RecordingResumeManager()
        let observerService = RecordingObserverService(onEnableDelivery: { sensors in
            for sensor in sensors {
                await observerStore.recordDeliveryEnabled(for: sensor)
            }
        })
        let logger = RecordingErrorLogger()
        let service = makeCheckService(
            sensorStore: sensorStore,
            observerStore: observerStore,
            healthKitManager: manager,
            observerService: observerService,
            logger: logger
        )

        let result = await service.runHealthCheck()

        #expect(observerService.enableDeliveryCalls == [[.sleep]])
        #expect(observerService.startObserverCalls.isEmpty)
        #expect(manager.resumeForCalls.isEmpty)
        #expect(result.sensorsReRegistered == [.sleep])
        #expect(result.failures.isEmpty)
        #expect(logger.count == 0)
    }

    @Test("A failed delivery repair lands in the aggregate error, not a throw")
    func failedDeliveryRepairIsAggregated() async throws {
        let sensorStore = MockSensorStoreForHealthCheck()
        try await sensorStore.setSensors([.sleep])
        let observerStore = HealthKitObserverStore()
        await observerStore.replaceObserver(observerQuery(for: .sleep), for: .sleep, stoppingDisplaced: { _ in }, executing: { _ in })
        let manager = RecordingResumeManager()
        let observerService = RecordingObserverService(onEnableDelivery: { _ in
            throw SahhaError(message: "delivery denied")
        })
        let logger = RecordingErrorLogger()
        let service = makeCheckService(
            sensorStore: sensorStore,
            observerStore: observerStore,
            healthKitManager: manager,
            observerService: observerService,
            logger: logger
        )

        let result = await service.runHealthCheck()

        #expect(result.failures.keys.contains(.sleep))
        let posted = logger.drain()
        #expect(posted.count == 1)
        let error = try #require(posted.first?.error as? SahhaError)
        #expect(error.message == "Observer re-registration failed for 1 sensor(s): sleep")
    }

    // MARK: Single-flight

    @Test("Concurrent checks coalesce into exactly one re-arm pass; a later check runs fresh")
    func concurrentChecksSingleFlight() async throws {
        let sensorStore = MockSensorStoreForHealthCheck()
        try await sensorStore.setSensors([.sleep])
        let observerStore = HealthKitObserverStore()   // empty: sleep is missing
        let gate = Gate()
        let manager = RecordingResumeManager(onResumeFor: { _ in
            await gate.waitUntilOpen()
        })
        let service = makeCheckService(
            sensorStore: sensorStore,
            observerStore: observerStore,
            healthKitManager: manager,
            logger: RecordingErrorLogger()
        )

        let tasks = (0 ..< 5).map { _ in
            Task { await service.runHealthCheck() }
        }
        // Let every call reach the service while the first pass is held open.
        try await Task.sleep(nanoseconds: 200_000_000)
        await gate.open()
        for task in tasks {
            _ = await task.value
        }

        #expect(manager.resumeForCalls.count == 1)

        // A sequential check after the pass completes is a new pass.
        _ = await service.runHealthCheck()
        #expect(manager.resumeForCalls.count == 2)
    }

    // MARK: Side isolation in the set-scoped resume

    @Test("resumeSensors(for:): a data-log failure is posted and does not block tag arming")
    func resumeForDataLogFailureDoesNotBlockTagSide() async throws {
        let storage = InMemoryStorage()
        storage.set(try JSONEncoder().encode(["sleep", "menstrual_flow"]), forKey: StorageKeys.UserDefaults.sensors)
        let marker = SahhaError(message: "data-log arming failed")
        let observerStore = HealthKitObserverStore()
        let tagCoordinator = ArmingTagCoordinator(observerStore: observerStore)
        let logger = RecordingErrorLogger()
        let manager = makeManager(
            sensorStore: SensorStore(storage: storage),
            dataLogCoordinator: ThrowingDataLogCoordinator(error: marker),
            tagCoordinator: tagCoordinator,
            logger: logger
        )

        await manager.resumeSensors(for: [.sleep, .menstrual_flow])

        #expect(await tagCoordinator.startCalls == [[.menstrual_flow]])
        let posted = logger.drain()
        #expect(posted.count == 1)
        #expect((posted.first?.error as? SahhaError)?.message == "data-log arming failed")
    }

    @Test("resumeSensors(for:): a tag failure is posted and does not block data-log arming")
    func resumeForTagFailureDoesNotBlockDataLogSide() async throws {
        let storage = InMemoryStorage()
        storage.set(try JSONEncoder().encode(["sleep", "menstrual_flow"]), forKey: StorageKeys.UserDefaults.sensors)
        let marker = SahhaError(message: "tag arming failed")
        let observerStore = HealthKitObserverStore()
        let dataLogCoordinator = ArmingDataLogCoordinator(observerStore: observerStore)
        let logger = RecordingErrorLogger()
        let manager = makeManager(
            sensorStore: SensorStore(storage: storage),
            dataLogCoordinator: dataLogCoordinator,
            tagCoordinator: ThrowingTagCoordinator(error: marker),
            logger: logger
        )

        await manager.resumeSensors(for: [.sleep, .menstrual_flow])

        #expect(await dataLogCoordinator.startCalls == [[.sleep]])
        let posted = logger.drain()
        #expect(posted.count == 1)
        #expect((posted.first?.error as? SahhaError)?.message == "tag arming failed")
    }

    @Test("Launch resume: a data-log failure is posted and does not block tag arming")
    func launchResumeIsolatesSides() async throws {
        let storage = InMemoryStorage()
        storage.set(try JSONEncoder().encode(["sleep", "menstrual_flow"]), forKey: StorageKeys.UserDefaults.sensors)
        let marker = SahhaError(message: "data-log arming failed")
        let observerStore = HealthKitObserverStore()
        let tagCoordinator = ArmingTagCoordinator(observerStore: observerStore)
        let logger = RecordingErrorLogger()
        let manager = makeManager(
            sensorStore: SensorStore(storage: storage),
            dataLogCoordinator: ThrowingDataLogCoordinator(error: marker),
            tagCoordinator: tagCoordinator,
            logger: logger
        )

        await manager.resumeSensors()

        #expect(await tagCoordinator.startCalls == [[.menstrual_flow]])
        let posted = logger.drain()
        #expect(posted.count == 1)
        #expect((posted.first?.error as? SahhaError)?.message == "data-log arming failed")
    }

    @Test("A stale missing set intersects with the fresh store read and arms nothing")
    func staleMissingSetArmsNothing() async throws {
        let storage = InMemoryStorage()
        storage.set(try JSONEncoder().encode(["sleep"]), forKey: StorageKeys.UserDefaults.sensors)
        let observerStore = HealthKitObserverStore()
        let dataLogCoordinator = ArmingDataLogCoordinator(observerStore: observerStore)
        let tagCoordinator = ArmingTagCoordinator(observerStore: observerStore)
        let logger = RecordingErrorLogger()
        let manager = makeManager(
            sensorStore: SensorStore(storage: storage),
            dataLogCoordinator: dataLogCoordinator,
            tagCoordinator: tagCoordinator,
            logger: logger
        )

        // heart_rate was torn down after the caller computed its missing set.
        await manager.resumeSensors(for: [.heart_rate])

        #expect(await dataLogCoordinator.startCalls.isEmpty)
        #expect(await tagCoordinator.startCalls.isEmpty)
        #expect(logger.count == 0)
    }

    // MARK: Tag-side repair end to end

    @Test("A tag-side missing sensor is armed via the tag coordinator")
    func tagSideMissingSensorArmedViaTagCoordinator() async throws {
        let storage = InMemoryStorage()
        storage.set(try JSONEncoder().encode(["sleep", "menstrual_flow"]), forKey: StorageKeys.UserDefaults.sensors)
        let sensorStore = SensorStore(storage: storage)
        let observerStore = HealthKitObserverStore()
        await armIntoStore(observerStore, [.sleep])   // the tag sensor is missing
        let dataLogCoordinator = ArmingDataLogCoordinator(observerStore: observerStore)
        let tagCoordinator = ArmingTagCoordinator(observerStore: observerStore)
        let logger = RecordingErrorLogger()
        let manager = makeManager(
            sensorStore: sensorStore,
            dataLogCoordinator: dataLogCoordinator,
            tagCoordinator: tagCoordinator,
            logger: logger
        )
        let service = makeCheckService(
            sensorStore: sensorStore,
            observerStore: observerStore,
            healthKitManager: manager,
            logger: logger
        )

        let result = await service.runHealthCheck()

        #expect(await tagCoordinator.startCalls == [[.menstrual_flow]])
        #expect(await dataLogCoordinator.startCalls.isEmpty)
        #expect(result.sensorsReRegistered == [.menstrual_flow])
        #expect(result.failures.isEmpty)
        #expect(logger.count == 0)
    }

    // MARK: Atomic observer replace

    @Test("Replacing an observer stops the displaced query")
    func replaceStopsDisplacedQuery() async throws {
        let store = HealthKitObserverStore()
        let recorder = QueryRecorder()
        let first = observerQuery(for: .sleep)
        let second = observerQuery(for: .sleep)

        await store.replaceObserver(first, for: .sleep, stoppingDisplaced: { recorder.recordStopped($0) }, executing: { recorder.recordExecuted($0) })
        await store.replaceObserver(second, for: .sleep, stoppingDisplaced: { recorder.recordStopped($0) }, executing: { recorder.recordExecuted($0) })

        #expect(recorder.executed == [first, second])
        #expect(recorder.stopped == [first])
        #expect(await store.getRegisteredKeys() == [SahhaSensor.sleep.rawValue])
    }

    @Test("No-orphan invariant: across concurrent re-arms, executed − stopped == registered")
    func noOrphanInvariantUnderConcurrentReplaces() async throws {
        let store = HealthKitObserverStore()
        let recorder = QueryRecorder()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 20 {
                group.addTask {
                    await store.replaceObserver(
                        observerQuery(for: .sleep),
                        for: .sleep,
                        stoppingDisplaced: { recorder.recordStopped($0) },
                        executing: { recorder.recordExecuted($0) }
                    )
                }
            }
        }

        let executed = recorder.executed
        let stopped = recorder.stopped
        #expect(executed.count == 20)
        #expect(executed.count - stopped.count == 1)
        #expect(await store.getRegisteredKeys() == [SahhaSensor.sleep.rawValue])
        // The one executed query never stopped is exactly the one still registered.
        let orphanCandidates = Set(executed.map(ObjectIdentifier.init)).subtracting(stopped.map(ObjectIdentifier.init))
        #expect(orphanCandidates.count == 1)
    }

    @Test("The observer service arms through the atomic replace: repeat arming leaks no queries")
    func repeatedArmingLeaksNoQueries() async throws {
        let healthStore = RecordingHealthStore()
        let observerStore = HealthKitObserverStore()
        let service = HealthKitObserverService(
            healthStore: healthStore,
            observerStore: observerStore,
            logger: NoopErrorLogger()
        )

        try await service.startObservers(for: [.heart_rate]) { _, _ in }
        try await service.startObservers(for: [.heart_rate]) { _, _ in }

        // Both queries executed, the displaced first one stopped, one registered:
        // repeated enableSensors no longer accumulates executing observers.
        #expect(healthStore.executedQueries.count == 2)
        #expect(healthStore.stoppedQueries.count == 1)
        #expect(healthStore.stoppedQueries.first === healthStore.executedQueries.first)
        #expect(await observerStore.getRegisteredKeys() == [SahhaSensor.heart_rate.rawValue])
    }

    // MARK: Per-sensor background delivery

    @Test("One denied type does not abort the rest: every sensor attempted, successes recorded, one aggregate throw")
    func backgroundDeliveryIsPerSensorIsolated() async throws {
        let healthStore = RecordingHealthStore()
        healthStore.failingBackgroundTypes = [SahhaSensor.heart_rate.hkSampleType!]
        let observerStore = HealthKitObserverStore()
        let service = HealthKitObserverService(
            healthStore: healthStore,
            observerStore: observerStore,
            logger: NoopErrorLogger()
        )

        await #expect(throws: SahhaError.self) {
            try await service.enableBackgroundDelivery(for: [.sleep, .heart_rate, .steps])
        }

        // All three types were attempted despite the failure...
        #expect(healthStore.enabledBackgroundTypes.count == 3)
        // ...and the two successes are recorded for the health check.
        #expect(await observerStore.getDeliveryEnabledKeys() == [SahhaSensor.sleep.rawValue, SahhaSensor.steps.rawValue])
    }

    @Test("Disabling delivery drops the record even when the underlying call fails")
    func disableDeliveryDropsRecordOnFailure() async throws {
        let healthStore = RecordingHealthStore()
        let observerStore = HealthKitObserverStore()
        await observerStore.recordDeliveryEnabled(for: .sleep)
        let service = HealthKitObserverService(
            healthStore: healthStore,
            observerStore: observerStore,
            logger: NoopErrorLogger()
        )
        healthStore.backgroundDeliveryError = NSError(domain: "test", code: 1)

        await #expect(throws: SahhaError.self) {
            try await service.disableBackgroundDelivery(for: [.sleep])
        }

        // A record without a live enable would only hide the sensor from the
        // health check; dropping it forces a safe re-enable instead.
        #expect(await observerStore.getDeliveryEnabledKeys().isEmpty)
    }
}
