import Testing
import Foundation
import HealthKit

@testable import Sahha

// Coverage for the non-wedging anchored-query timeout and the anchor-save
// loop-break, in both coordinators.
//
// The old implementation raced the query against a timeout inside a throwing task
// group. A task group awaits ALL of its children before returning, so when the
// query child parked forever (a result handler that never fires) the timeout
// error could not escape the group: the sensor's slot in SingleTaskActorMap
// stayed occupied for the life of the process, every later trigger for that
// sensor awaited the wedged task, and the HealthKit observer's completion
// handler never ran — which leads iOS to suspend background delivery entirely.
// Separately, a failed anchor save was swallowed without advancing the anchor,
// so the query loop re-fetched the identical page forever.

// MARK: - Shared stubs

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

/// Loads return a fixed anchor so runs take the ongoing (anchor != nil) path;
/// saves succeed.
private actor WorkingAnchorStore: HealthKitAnchorStoreProtocol {
    private var anchors: [String: HKQueryAnchor] = [:]

    func saveAnchor(_ anchor: HKQueryAnchor, forKey key: String) throws { anchors[key] = anchor }
    func loadAnchor(forKey key: String) throws -> HKQueryAnchor? { anchors[key] ?? HKQueryAnchor(fromValue: 1) }
}

/// Anchor store whose saves always fail, as when the underlying storage write
/// throws; loads return a fixed anchor so runs take the ongoing path.
private actor FailingSaveAnchorStore: HealthKitAnchorStoreProtocol {
    func saveAnchor(_ anchor: HKQueryAnchor, forKey key: String) throws {
        throw SahhaError(message: "anchor save failed")
    }
    func loadAnchor(forKey key: String) throws -> HKQueryAnchor? { HKQueryAnchor(fromValue: 1) }
}

private struct NullDataLogNormaliser: HKSampleToDataLogNormaliserProtocol {
    func normalise(_ sample: HKSample, profileId: String?) -> [DataLog] { [] }
}

private actor NullDataLogPipeline: DataLogPipelineProtocol {
    func ingest(_ log: DataLog) async {}
    func ingest(_ logs: [DataLog]) async {}
}

// The tag doubles (NullTagNormaliser, NullTagPipeline) live in
// TestSupport/TagTestDoubles.swift, where `Tag` is unambiguous.

// MARK: - Helpers

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

private func waitUntil(timeout: Double = 5, _ condition: @Sendable () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
    return condition()
}

private func makeDataLogCoordinator(
    anchorQuery: HealthKitAnchorQueryServiceProtocol,
    anchorStore: HealthKitAnchorStoreProtocol,
    logger: ErrorLoggerProtocol,
    queryTimeout: TimeInterval
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
        queryTimeout: queryTimeout
    )
}

private func makeTagCoordinator(
    anchorQuery: HealthKitAnchorQueryServiceProtocol,
    anchorStore: HealthKitAnchorStoreProtocol,
    logger: ErrorLoggerProtocol,
    queryTimeout: TimeInterval
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
        queryTimeout: queryTimeout
    )
}

// MARK: - DataLog coordinator

@Suite("DataLog anchored-query wedge")
struct DataLogAnchoredQueryWedgeTests {

    @Test("A never-completing query returns via timeout and releases the sensor's task slot for a fresh query")
    func timeoutReleasesTaskSlot() async throws {
        let service = ScriptedAnchorQueryService(script: [
            .parkForever,
            .batch([heartRateSample()], HKQueryAnchor(fromValue: 2)),
        ])
        let coordinator = makeDataLogCoordinator(
            anchorQuery: service,
            anchorStore: WorkingAnchorStore(),
            logger: RecordingErrorLogger(),
            queryTimeout: 0.3
        )

        // First trigger: the query parks; the coordinator must get control back.
        let first = await coordinator.querySensors([.heart_rate])
        let firstResult = try #require(first.first { $0.sensor == .heart_rate })
        #expect(firstResult.status == .failed)
        #expect(firstResult.errorDescription?.contains("heart_rate") == true)

        // The slot must be free again: a second trigger issues a fresh query
        // instead of awaiting the wedged one.
        let second = await coordinator.querySensors([.heart_rate])
        let secondResult = try #require(second.first { $0.sensor == .heart_rate })
        #expect(secondResult.status == .success)
        #expect(secondResult.samplesFetched == 1)
        #expect(service.callCount == 3)  // park, batch, empty terminator
    }

    @Test("The timeout is posted with the sensor name")
    func timeoutIsPostedWithSensorName() async {
        let logger = RecordingErrorLogger()
        let coordinator = makeDataLogCoordinator(
            anchorQuery: ScriptedAnchorQueryService(script: [.parkForever]),
            anchorStore: WorkingAnchorStore(),
            logger: logger,
            queryTimeout: 0.3
        )

        _ = await coordinator.querySensors([.heart_rate])

        let posted = logger.drain()
        #expect(posted.contains {
            $0.error.localizedDescription.contains("timed out") &&
            $0.error.localizedDescription.contains("heart_rate")
        })
    }

    @Test("Stopping collection mid-query stops the underlying HealthKit query and returns promptly")
    func stopCollectionStopsUnderlyingQuery() async throws {
        let store = RecordingHealthStore()
        let coordinator = makeDataLogCoordinator(
            anchorQuery: HealthKitAnchorQueryService(healthStore: store),
            anchorStore: WorkingAnchorStore(),
            logger: RecordingErrorLogger(),
            queryTimeout: 30
        )

        let queryTask = Task { await coordinator.querySensors([.heart_rate]) }
        // The recording store never fires result handlers, so the query parks.
        #expect(await waitUntil { store.executedQueries.count == 1 })

        try await coordinator.stopDataLogCollection(for: [.heart_rate])

        // Cancellation must reach the service: query stopped, caller resumed
        // long before the 30s timeout, and the run reported as benign.
        let results = await queryTask.value
        #expect(results.first?.status == .noSamples)
        #expect(store.stoppedQueries.count == 1)
        #expect(store.stoppedQueries.first === store.executedQueries.first)
    }

    @Test("A failing anchor save breaks the query loop instead of re-fetching the same page forever, and is posted")
    func failingAnchorSaveBreaksLoop() async throws {
        let logger = RecordingErrorLogger()
        let service = ScriptedAnchorQueryService(script: [
            .repeatingBatch([heartRateSample()], HKQueryAnchor(fromValue: 2)),
        ])
        let coordinator = makeDataLogCoordinator(
            anchorQuery: service,
            anchorStore: FailingSaveAnchorStore(),
            logger: logger,
            queryTimeout: 5
        )

        let results = await coordinator.querySensors([.heart_rate])

        let result = try #require(results.first { $0.sensor == .heart_rate })
        #expect(result.samplesFetched == 1)
        #expect(result.anchorUpdated == false)
        #expect(service.callCount == 1)
        #expect(logger.drain().contains { $0.error.localizedDescription.contains("anchor save failed") })
    }
}

// MARK: - Tag coordinator (mirrored)

@Suite("Tag anchored-query wedge")
struct TagAnchoredQueryWedgeTests {

    @Test("A never-completing query returns via timeout and releases the sensor's task slot for a fresh query")
    func timeoutReleasesTaskSlot() async throws {
        let service = ScriptedAnchorQueryService(script: [
            .parkForever,
            .batch([crampsSample()], HKQueryAnchor(fromValue: 2)),
        ])
        let coordinator = makeTagCoordinator(
            anchorQuery: service,
            anchorStore: WorkingAnchorStore(),
            logger: RecordingErrorLogger(),
            queryTimeout: 0.3
        )

        let first = await coordinator.querySensors([.abdominal_cramps])
        let firstResult = try #require(first.first { $0.sensor == .abdominal_cramps })
        #expect(firstResult.status == .failed)
        #expect(firstResult.errorDescription?.contains("abdominal_cramps") == true)

        let second = await coordinator.querySensors([.abdominal_cramps])
        let secondResult = try #require(second.first { $0.sensor == .abdominal_cramps })
        #expect(secondResult.status == .success)
        #expect(secondResult.samplesFetched == 1)
        #expect(service.callCount == 3)  // park, batch, empty terminator
    }

    @Test("The timeout is posted with the sensor name")
    func timeoutIsPostedWithSensorName() async {
        let logger = RecordingErrorLogger()
        let coordinator = makeTagCoordinator(
            anchorQuery: ScriptedAnchorQueryService(script: [.parkForever]),
            anchorStore: WorkingAnchorStore(),
            logger: logger,
            queryTimeout: 0.3
        )

        _ = await coordinator.querySensors([.abdominal_cramps])

        let posted = logger.drain()
        #expect(posted.contains {
            $0.error.localizedDescription.contains("timed out") &&
            $0.error.localizedDescription.contains("abdominal_cramps")
        })
    }

    @Test("Stopping collection mid-query stops the underlying HealthKit query and returns promptly")
    func stopCollectionStopsUnderlyingQuery() async throws {
        let store = RecordingHealthStore()
        let coordinator = makeTagCoordinator(
            anchorQuery: HealthKitAnchorQueryService(healthStore: store),
            anchorStore: WorkingAnchorStore(),
            logger: RecordingErrorLogger(),
            queryTimeout: 30
        )

        let queryTask = Task { await coordinator.querySensors([.abdominal_cramps]) }
        #expect(await waitUntil { store.executedQueries.count == 1 })

        try await coordinator.stopTagCollection(for: [.abdominal_cramps])

        let results = await queryTask.value
        #expect(results.first?.status == .noSamples)
        #expect(store.stoppedQueries.count == 1)
        #expect(store.stoppedQueries.first === store.executedQueries.first)
    }

    @Test("A failing anchor save breaks the query loop instead of re-fetching the same page forever, and is posted")
    func failingAnchorSaveBreaksLoop() async throws {
        let logger = RecordingErrorLogger()
        let service = ScriptedAnchorQueryService(script: [
            .repeatingBatch([crampsSample()], HKQueryAnchor(fromValue: 2)),
        ])
        let coordinator = makeTagCoordinator(
            anchorQuery: service,
            anchorStore: FailingSaveAnchorStore(),
            logger: logger,
            queryTimeout: 5
        )

        let results = await coordinator.querySensors([.abdominal_cramps])

        let result = try #require(results.first { $0.sensor == .abdominal_cramps })
        #expect(result.samplesFetched == 1)
        #expect(result.anchorUpdated == false)
        #expect(service.callCount == 1)
        #expect(logger.drain().contains { $0.error.localizedDescription.contains("anchor save failed") })
    }
}
