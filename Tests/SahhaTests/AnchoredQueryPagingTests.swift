import Foundation
import HealthKit
import Testing

@testable import Sahha

// Coverage for the anchored-query paging both coordinators share (AnchoredQueryPager):
//
// - a cap on concurrent anchored queries, shared by the data-log and tag coordinators,
//   whose timeout starts only once a page holds a slot;
// - a page size that shrinks for a sensor after each timeout (500, 100, 20) and returns
//   to full size once a run catches up to an empty page;
// - timeout reports that carry the page's context, with the first timeout at the
//   minimum page size posted from a call site of its own.
//
// Before this, a page too slow to return in 30s was retried unchanged on every
// trigger, so the sensor never progressed, and the one report per process said only
// the sensor and the budget.

// MARK: - Stubs

private final class NoopObserverService: HealthKitObserverServiceProtocol, @unchecked Sendable {
    func startObservers(for sensors: Set<SahhaSensor>, handler: @escaping HealthKitObserverHandler) async throws {}
    func stopObservers(for sensors: Set<SahhaSensor>) async throws {}
    func enableBackgroundDelivery(for sensors: Set<SahhaSensor>) async throws {}
    func disableBackgroundDelivery(for sensors: Set<SahhaSensor>) async throws {}
    func dispose() async {}
}

private struct StubProfileIdProvider: ProfileIdProviderProtocol {
    func profileId() -> String? { "test-profile" }
}

/// Saves succeed. Loads return the saved anchor, else `initialAnchor`, where nil
/// means the sensor has never synced.
private actor MemoryAnchorStore: HealthKitAnchorStoreProtocol {
    private let initialAnchor: HKQueryAnchor?
    private var anchors: [String: HKQueryAnchor] = [:]

    init(initialAnchor: HKQueryAnchor? = HKQueryAnchor(fromValue: 1)) {
        self.initialAnchor = initialAnchor
    }

    func saveAnchor(_ anchor: HKQueryAnchor, forKey key: String) throws { anchors[key] = anchor }
    func loadAnchor(forKey key: String) throws -> HKQueryAnchor? { anchors[key] ?? initialAnchor }
}

private struct NullDataLogNormaliser: HKSampleToDataLogNormaliserProtocol {
    func normalise(_ sample: HKSample, profileId: String?) -> [DataLog] { [] }
}

private actor NullDataLogPipeline: DataLogPipelineProtocol {
    func ingest(_ log: DataLog) async {}
    func ingest(_ logs: [DataLog]) async {}
}

private struct StubApplicationStateProvider: ApplicationStateProviding {
    let value: ApplicationStateSnapshot

    func snapshot() async -> ApplicationStateSnapshot { value }
}

/// Every call sleeps for `delay` and then returns an empty page, while recording the
/// most calls that were ever in flight at once.
private final class ConcurrencyProbeAnchorQueryService: HealthKitAnchorQueryServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private let delay: TimeInterval
    private var inFlight = 0
    private var _peakInFlight = 0
    private var _callCount = 0

    init(delay: TimeInterval) {
        self.delay = delay
    }

    var peakInFlight: Int {
        lock.lock()
        defer { lock.unlock() }
        return _peakInFlight
    }

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _callCount
    }

    func runAnchorQuery(
        for sampleType: HKSampleType,
        predicate: NSPredicate?,
        anchor: HKQueryAnchor?,
        limit: Int
    ) async throws -> ([HKSample], HKQueryAnchor?) {
        enter()
        defer { leave() }
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        return ([], nil)
    }

    // Locking lives in synchronous helpers: NSLock is unavailable from async contexts.

    private func enter() {
        lock.lock()
        defer { lock.unlock() }
        inFlight += 1
        _callCount += 1
        _peakInFlight = max(_peakInFlight, inFlight)
    }

    private func leave() {
        lock.lock()
        defer { lock.unlock() }
        inFlight -= 1
    }
}

// MARK: - Helpers

/// Data-log sensors backed by a HealthKit sample type, for fan-out runs.
private let fanOutSensors: [SahhaSensor] = [
    .heart_rate, .steps, .resting_heart_rate, .respiratory_rate,
    .active_energy_burned, .basal_energy_burned, .oxygen_saturation, .walking_speed,
]

private func heartRateSample() -> HKQuantitySample {
    let type = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    let bpm = HKUnit.count().unitDivided(by: .minute())
    let date = Date().addingTimeInterval(-24 * 3600)
    return HKQuantitySample(type: type, quantity: HKQuantity(unit: bpm, doubleValue: 70), start: date, end: date)
}

private func crampsSample() -> HKCategorySample {
    let type = HKCategoryType.categoryType(forIdentifier: .abdominalCramps)!
    let date = Date().addingTimeInterval(-24 * 3600)
    return HKCategorySample(type: type, value: HKCategoryValueSeverity.moderate.rawValue, start: date, end: date)
}

private func waitUntil(timeout: Double = 5, _ condition: @Sendable () async -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if await condition() { return true }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    return await condition()
}

/// The anchored-query timeouts a coordinator posted, with the line each was posted from.
private func postedTimeouts(_ logger: RecordingErrorLogger) -> [(error: AnchoredQueryTimeoutError, line: UInt)] {
    logger.drain().compactMap { posted in
        (posted.error as? AnchoredQueryTimeoutError).map { (error: $0, line: posted.line) }
    }
}

private func makeDataLogCoordinator(
    anchorQuery: HealthKitAnchorQueryServiceProtocol,
    anchorStore: HealthKitAnchorStoreProtocol = MemoryAnchorStore(),
    logger: ErrorLoggerProtocol = RecordingErrorLogger(),
    queryTimeout: TimeInterval,
    querySlots: AsyncSemaphore = AsyncSemaphore(value: AnchoredQueryPager.defaultConcurrencyLimit),
    appStateProvider: ApplicationStateProviding? = nil
) -> HealthKitDataLogCoordinator {
    HealthKitDataLogCoordinator(
        observerService: NoopObserverService(),
        anchorQueryService: anchorQuery,
        anchorStore: anchorStore,
        normaliser: NullDataLogNormaliser(),
        profileIdProvider: StubProfileIdProvider(),
        dataLogPipeline: NullDataLogPipeline(),
        circuitBreaker: nil,
        logger: logger,
        queryTimeout: queryTimeout,
        querySlots: querySlots,
        appStateProvider: appStateProvider
    )
}

private func makeTagCoordinator(
    anchorQuery: HealthKitAnchorQueryServiceProtocol,
    anchorStore: HealthKitAnchorStoreProtocol = MemoryAnchorStore(),
    logger: ErrorLoggerProtocol = RecordingErrorLogger(),
    queryTimeout: TimeInterval,
    querySlots: AsyncSemaphore = AsyncSemaphore(value: AnchoredQueryPager.defaultConcurrencyLimit)
) -> HealthKitTagCoordinator {
    HealthKitTagCoordinator(
        observerService: NoopObserverService(),
        anchorQueryService: anchorQuery,
        anchorStore: anchorStore,
        normaliser: NullTagNormaliser(),
        profileIdProvider: StubProfileIdProvider(),
        tagPipeline: NullTagPipeline(),
        circuitBreaker: nil,
        logger: logger,
        queryTimeout: queryTimeout,
        querySlots: querySlots
    )
}

// MARK: - Concurrency cap

@Suite("Anchored-query concurrency cap")
struct AnchoredQueryConcurrencyCapTests {

    @Test("A fan-out across many sensors never runs more anchored queries at once than there are slots")
    func fanOutIsCapped() async {
        let probe = ConcurrencyProbeAnchorQueryService(delay: 0.15)
        let coordinator = makeDataLogCoordinator(
            anchorQuery: probe,
            queryTimeout: 5,
            querySlots: AsyncSemaphore(value: 2)
        )

        let results = await coordinator.querySensors(Set(fanOutSensors))

        #expect(results.count == fanOutSensors.count)
        #expect(results.allSatisfy { $0.status == .noSamples })
        #expect(probe.callCount == fanOutSensors.count)
        #expect(probe.peakInFlight == 2)
    }

    @Test("Time spent queued for a slot does not count toward a page's timeout")
    func queueTimeIsNotTimed() async {
        // One slot, five sensors, 0.3s per query: the last sensor queues about 1.2s
        // for its slot, past the 1s timeout, while its own query takes 0.3s.
        let logger = RecordingErrorLogger()
        let probe = ConcurrencyProbeAnchorQueryService(delay: 0.3)
        let coordinator = makeDataLogCoordinator(
            anchorQuery: probe,
            logger: logger,
            queryTimeout: 1,
            querySlots: AsyncSemaphore(value: 1)
        )

        let results = await coordinator.querySensors(Set(fanOutSensors.prefix(5)))

        #expect(results.count == 5)
        #expect(results.allSatisfy { $0.status == .noSamples })
        #expect(postedTimeouts(logger).isEmpty)
        #expect(probe.peakInFlight == 1)
    }

    @Test("The data-log and tag coordinators queue for one shared pool of slots")
    func coordinatorsShareSlots() async {
        let probe = ConcurrencyProbeAnchorQueryService(delay: 0.1)
        let slots = AsyncSemaphore(value: 1)
        let dataLog = makeDataLogCoordinator(anchorQuery: probe, queryTimeout: 5, querySlots: slots)
        let tags = makeTagCoordinator(anchorQuery: probe, queryTimeout: 5, querySlots: slots)

        async let dataLogResults = dataLog.querySensors([.heart_rate, .steps])
        async let tagResults = tags.querySensors([.abdominal_cramps, .acne])
        let results = await dataLogResults + tagResults

        #expect(results.count == 4)
        #expect(results.allSatisfy { $0.status == .noSamples })
        #expect(probe.callCount == 4)
        #expect(probe.peakInFlight == 1)
    }

    @Test("A sensor stopped while queued for a slot leaves the queue without querying")
    func stopWhileQueued() async throws {
        let probe = ConcurrencyProbeAnchorQueryService(delay: 1)
        let slots = AsyncSemaphore(value: 1)
        let coordinator = makeDataLogCoordinator(anchorQuery: probe, queryTimeout: 5, querySlots: slots)

        let holder = Task { await coordinator.querySensors([.heart_rate]) }
        #expect(await waitUntil { probe.callCount == 1 })
        let queued = Task { await coordinator.querySensors([.steps]) }
        #expect(await waitUntil { await slots.load.waiting == 1 })

        try await coordinator.stopDataLogCollection(for: [.steps])

        // Stopping is benign, not a failure, and the stopped sensor never queried.
        let queuedResults = await queued.value
        #expect(queuedResults.first?.status == .noSamples)
        #expect(probe.callCount == 1)

        _ = await holder.value
        #expect(await slots.load == AsyncSemaphore.Load(inUse: 0, waiting: 0, capacity: 1))
    }
}

// MARK: - Adaptive page size

@Suite("Adaptive anchored-query page size")
struct AdaptiveAnchoredQueryPageSizeTests {

    @Test("Each timeout shrinks the sensor's next page, down to a floor")
    func timeoutsShrinkPages() async {
        let service = ScriptedAnchorQueryService(script: [.parkForever, .parkForever, .parkForever])
        let coordinator = makeDataLogCoordinator(anchorQuery: service, queryTimeout: 0.2)

        for _ in 0..<3 {
            let results = await coordinator.querySensors([.heart_rate])
            #expect(results.first?.status == .failed)
        }
        // The script has run dry, so this run gets an empty page, at the floor size.
        _ = await coordinator.querySensors([.heart_rate])

        #expect(service.capturedLimits == [500, 100, 20, 20])
    }

    @Test("A sensor goes back to full-size pages once a run catches up, not after one good page")
    func catchingUpRestoresFullSize() async {
        let service = ScriptedAnchorQueryService(script: [
            .parkForever,
            .batch([heartRateSample()], HKQueryAnchor(fromValue: 2)),
        ])
        let coordinator = makeDataLogCoordinator(anchorQuery: service, queryTimeout: 0.2)

        _ = await coordinator.querySensors([.heart_rate])  // times out at full size
        let catchUp = await coordinator.querySensors([.heart_rate])  // a page, then the empty page
        _ = await coordinator.querySensors([.heart_rate])  // caught up

        #expect(catchUp.first?.status == .success)
        #expect(service.capturedLimits == [500, 100, 100, 500])
    }

    @Test("Shrinking applies only to the sensor that timed out")
    func shrinkingIsPerSensor() async {
        let service = ScriptedAnchorQueryService(script: [.parkForever])
        let coordinator = makeDataLogCoordinator(anchorQuery: service, queryTimeout: 0.2)

        _ = await coordinator.querySensors([.heart_rate])  // times out
        _ = await coordinator.querySensors([.steps])
        _ = await coordinator.querySensors([.heart_rate])

        #expect(service.capturedLimits == [500, 500, 100])
    }

    @Test("Tag sensors shrink their pages after timeouts too")
    func tagTimeoutsShrinkPages() async {
        let service = ScriptedAnchorQueryService(script: [
            .parkForever,
            .parkForever,
            .batch([crampsSample()], HKQueryAnchor(fromValue: 2)),
        ])
        let coordinator = makeTagCoordinator(anchorQuery: service, queryTimeout: 0.2)

        _ = await coordinator.querySensors([.abdominal_cramps])
        _ = await coordinator.querySensors([.abdominal_cramps])
        let catchUp = await coordinator.querySensors([.abdominal_cramps])
        _ = await coordinator.querySensors([.abdominal_cramps])

        #expect(catchUp.first?.status == .success)
        #expect(service.capturedLimits == [500, 100, 20, 20, 500])
    }
}

// MARK: - Timeout diagnostics

@Suite("Anchored-query timeout diagnostics")
struct AnchoredQueryTimeoutDiagnosticsTests {

    @Test("A timeout posts the page's context in the error body and keeps the message stable")
    func timeoutCarriesContext() async throws {
        let logger = RecordingErrorLogger()
        let appState = ApplicationStateSnapshot(
            state: "background",
            isProtectedDataAvailable: true,
            backgroundTimeRemaining: 12.5
        )
        let coordinator = makeDataLogCoordinator(
            anchorQuery: ScriptedAnchorQueryService(script: [.parkForever]),
            anchorStore: MemoryAnchorStore(initialAnchor: nil),
            logger: logger,
            queryTimeout: 0.2,
            appStateProvider: StubApplicationStateProvider(value: appState)
        )

        let results = await coordinator.querySensors([.steps])

        let timeout = try #require(postedTimeouts(logger).first?.error)
        #expect(timeout.sensor == .steps)
        #expect(timeout.context.limit == 500)
        #expect(timeout.context.nextLimit == 100)
        #expect(timeout.context.isInitialSync)
        #expect(timeout.context.pagesCompleted == 0)
        #expect(timeout.context.elapsed >= 0.2)
        #expect(timeout.context.slots == AsyncSemaphore.Load(
            inUse: 1,
            waiting: 0,
            capacity: AnchoredQueryPager.defaultConcurrencyLimit
        ))
        #expect(timeout.context.appState == appState)

        let message = timeout.localizedDescription
        #expect(message.hasPrefix("HealthKit anchor query timed out for sensor steps after"))
        #expect(!message.contains("limit"))
        #expect(results.first?.errorDescription == message)

        let body = String(describing: timeout)
        #expect(body.contains("sensor: steps"))
        #expect(body.contains("limit: 500"))
        #expect(body.contains("initialSync: true"))
        #expect(body.contains("slotsInUse: 1/\(AnchoredQueryPager.defaultConcurrencyLimit)"))
        #expect(body.contains("app: (background, protectedData: available, backgroundTimeRemaining: 12.5s)"))
    }

    @Test("A timeout counts the pages its run completed first, and those pages stand")
    func timeoutCountsCompletedPages() async throws {
        let logger = RecordingErrorLogger()
        let coordinator = makeDataLogCoordinator(
            anchorQuery: ScriptedAnchorQueryService(script: [
                .batch([heartRateSample()], HKQueryAnchor(fromValue: 2)),
                .parkForever,
            ]),
            logger: logger,
            queryTimeout: 0.2
        )

        let results = await coordinator.querySensors([.heart_rate])

        let timeout = try #require(postedTimeouts(logger).first?.error)
        #expect(timeout.context.pagesCompleted == 1)
        #expect(!timeout.context.isInitialSync)
        #expect(timeout.context.appState == nil)
        #expect(String(describing: timeout).contains("app: unknown"))
        let result = try #require(results.first)
        #expect(result.status == .failed)
        #expect(result.samplesFetched == 1)
        #expect(result.anchorUpdated)
    }

    @Test("The first timeout at the minimum page size is posted from a call site of its own")
    func floorTimeoutHasItsOwnSite() async throws {
        let logger = RecordingErrorLogger()
        let coordinator = makeDataLogCoordinator(
            anchorQuery: ScriptedAnchorQueryService(script: [.parkForever, .parkForever, .parkForever]),
            logger: logger,
            queryTimeout: 0.2
        )

        for _ in 0..<3 {
            _ = await coordinator.querySensors([.heart_rate])
        }

        // The production logger posts each call site once, so the floor timeout needs
        // a site of its own to be seen after the first timeout.
        let posted = postedTimeouts(logger)
        try #require(posted.count == 3)
        #expect(posted.map { $0.error.context.limit } == [500, 100, 20])
        #expect(posted[0].line == posted[1].line)
        #expect(posted[2].line != posted[0].line)
        #expect(!posted[0].error.isAtMinimumPageSize)
        #expect(posted[2].error.isAtMinimumPageSize)
        #expect(!posted[0].error.localizedDescription.contains("minimum page size"))
        #expect(posted[2].error.localizedDescription.contains("even at the minimum page size of 20"))
    }

    @Test("Tag timeouts carry the context and post the floor from a call site of its own")
    func tagFloorTimeoutHasItsOwnSite() async throws {
        let logger = RecordingErrorLogger()
        let coordinator = makeTagCoordinator(
            anchorQuery: ScriptedAnchorQueryService(script: [.parkForever, .parkForever, .parkForever]),
            logger: logger,
            queryTimeout: 0.2
        )

        for _ in 0..<3 {
            _ = await coordinator.querySensors([.abdominal_cramps])
        }

        let posted = postedTimeouts(logger)
        try #require(posted.count == 3)
        #expect(posted.allSatisfy { $0.error.sensor == .abdominal_cramps })
        #expect(posted.map { $0.error.context.limit } == [500, 100, 20])
        #expect(posted[0].line == posted[1].line)
        #expect(posted[2].line != posted[0].line)
        #expect(posted[2].error.localizedDescription.contains("even at the minimum page size of 20"))
    }
}
