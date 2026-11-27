import Foundation
import HealthKit
import Testing

@testable import Sahha

// HealthKit returns deleted objects in anchored-query pages and counts them toward the
// page limit, so after a run of deletions longer than a page (a sync app rewriting
// history, a removed app's data) a page arrives with deletions and no samples.
//
// Before this, both coordinators read any sample-free page as "caught up": they stopped
// without saving the anchor HealthKit had advanced, so every later run fetched the same
// deletions again and the sensor never reached the samples behind them. It stalled
// silently, reporting no samples and no error. Seen on the iOS 27 simulator after 105k
// step deletions: 210 pages of 500 deletions came before the first sample.

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

/// Starts with a saved anchor (an incremental sync) and records every anchor saved.
private actor RecordingAnchorStore: HealthKitAnchorStoreProtocol {
    private var anchors: [String: HKQueryAnchor] = [:]
    private(set) var saved: [HKQueryAnchor] = []

    init(initial: HKQueryAnchor, for sensor: SahhaSensor) {
        anchors[sensor.rawValue] = initial
    }

    func saveAnchor(_ anchor: HKQueryAnchor, forKey key: String) throws {
        anchors[key] = anchor
        saved.append(anchor)
    }

    func loadAnchor(forKey key: String) throws -> HKQueryAnchor? { anchors[key] }
}

private actor CountingDataLogPipeline: DataLogPipelineProtocol {
    private(set) var count = 0
    func ingest(_ log: DataLog) async { count += 1 }
    func ingest(_ logs: [DataLog]) async { count += logs.count }
}

// MARK: - Helpers

private func heartRateSample() -> HKQuantitySample {
    let type = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    let bpm = HKUnit.count().unitDivided(by: .minute())
    let date = Date().addingTimeInterval(-3600)
    return HKQuantitySample(type: type, quantity: HKQuantity(unit: bpm, doubleValue: 70), start: date, end: date)
}

private func crampsSample() -> HKCategorySample {
    let type = HKCategoryType.categoryType(forIdentifier: .abdominalCramps)!
    let date = Date().addingTimeInterval(-3600)
    return HKCategorySample(type: type, value: HKCategoryValueSeverity.moderate.rawValue, start: date, end: date)
}

private func makeDataLogCoordinator(
    anchorQuery: HealthKitAnchorQueryServiceProtocol,
    anchorStore: HealthKitAnchorStoreProtocol,
    pipeline: DataLogPipelineProtocol,
    logger: ErrorLoggerProtocol
) -> HealthKitDataLogCoordinator {
    HealthKitDataLogCoordinator(
        observerService: NoopObserverService(),
        anchorQueryService: anchorQuery,
        anchorStore: anchorStore,
        normaliser: HKSampleToDataLogNormaliserRegistry(),
        profileIdProvider: StubProfileIdProvider(),
        dataLogPipeline: pipeline,
        logger: logger
    )
}

private func makeTagCoordinator(
    anchorQuery: HealthKitAnchorQueryServiceProtocol,
    anchorStore: HealthKitAnchorStoreProtocol,
    logger: ErrorLoggerProtocol
) -> HealthKitTagCoordinator {
    HealthKitTagCoordinator(
        observerService: NoopObserverService(),
        anchorQueryService: anchorQuery,
        anchorStore: anchorStore,
        normaliser: NullTagNormaliser(),
        profileIdProvider: StubProfileIdProvider(),
        tagPipeline: NullTagPipeline(),
        logger: logger
    )
}

// MARK: - Tests

@Suite("Anchored-query pages that hold only deletions")
struct AnchoredQueryDeletionPageTests {
    @Test("Data logs: pages of deletions are paged through, and the samples behind them are collected")
    func dataLogCoordinatorPagesThroughDeletions() async {
        let start = HKQueryAnchor(fromValue: 1)
        let afterFirst = HKQueryAnchor(fromValue: 501)
        let afterSecond = HKQueryAnchor(fromValue: 1001)
        let afterSamples = HKQueryAnchor(fromValue: 1003)
        let service = ScriptedAnchorQueryService(script: [
            .deletions(500, afterFirst),
            .deletions(500, afterSecond),
            .batch([heartRateSample(), heartRateSample()], afterSamples),
        ])
        let store = RecordingAnchorStore(initial: start, for: .heart_rate)
        let pipeline = CountingDataLogPipeline()
        let logger = RecordingErrorLogger()
        let coordinator = makeDataLogCoordinator(anchorQuery: service, anchorStore: store, pipeline: pipeline, logger: logger)

        let result = await coordinator.querySensors([.heart_rate]).first

        #expect(result?.status == .success)
        #expect(result?.samplesFetched == 2)
        #expect(await pipeline.count == 2)
        // Each deletion page's anchor is kept, so a run stopped part-way resumes past
        // the deletions it has already read.
        let saved = await store.saved
        #expect(saved.count == 3)
        #expect(saved.last === afterSamples)
        // Two deletion pages, the samples page, then the empty page that ends the run.
        #expect(service.callCount == 4)
        #expect(logger.drain().isEmpty)
    }

    @Test("Data logs: a run that finds only deletions saves the anchor, so the next run starts past them")
    func dataLogCoordinatorSavesAnchorForDeletionOnlyRun() async {
        let start = HKQueryAnchor(fromValue: 1)
        let afterDeletions = HKQueryAnchor(fromValue: 501)
        let service = ScriptedAnchorQueryService(script: [.deletions(500, afterDeletions)])
        let store = RecordingAnchorStore(initial: start, for: .heart_rate)
        let coordinator = makeDataLogCoordinator(
            anchorQuery: service,
            anchorStore: store,
            pipeline: CountingDataLogPipeline(),
            logger: RecordingErrorLogger()
        )

        let result = await coordinator.querySensors([.heart_rate]).first

        #expect(result?.status == .noSamples)
        #expect(result?.anchorUpdated == true)
        #expect((try? await store.loadAnchor(for: .heart_rate)) === afterDeletions)
    }

    @Test("Data logs: an empty page, with no samples and no deletions, still ends the run")
    func dataLogCoordinatorStopsOnEmptyPage() async {
        let start = HKQueryAnchor(fromValue: 1)
        let service = ScriptedAnchorQueryService(script: [])
        let store = RecordingAnchorStore(initial: start, for: .heart_rate)
        let coordinator = makeDataLogCoordinator(
            anchorQuery: service,
            anchorStore: store,
            pipeline: CountingDataLogPipeline(),
            logger: RecordingErrorLogger()
        )

        let result = await coordinator.querySensors([.heart_rate]).first

        #expect(result?.status == .noSamples)
        #expect(result?.anchorUpdated == false)
        #expect(service.callCount == 1)
        #expect(await store.saved.isEmpty)
    }

    @Test("Tags: pages of deletions are paged through, and the samples behind them are collected")
    func tagCoordinatorPagesThroughDeletions() async {
        let start = HKQueryAnchor(fromValue: 1)
        let afterDeletions = HKQueryAnchor(fromValue: 501)
        let afterSample = HKQueryAnchor(fromValue: 502)
        let service = ScriptedAnchorQueryService(script: [
            .deletions(500, afterDeletions),
            .batch([crampsSample()], afterSample),
        ])
        let store = RecordingAnchorStore(initial: start, for: .abdominal_cramps)
        let logger = RecordingErrorLogger()
        let coordinator = makeTagCoordinator(anchorQuery: service, anchorStore: store, logger: logger)

        let result = await coordinator.querySensors([.abdominal_cramps]).first

        #expect(result?.status == .success)
        #expect(result?.samplesFetched == 1)
        #expect((try? await store.loadAnchor(for: .abdominal_cramps)) === afterSample)
        #expect(service.callCount == 3)
        #expect(logger.drain().isEmpty)
    }
}
