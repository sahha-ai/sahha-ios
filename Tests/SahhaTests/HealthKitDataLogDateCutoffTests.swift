import Foundation
import HealthKit
import Testing

@testable import Sahha

// Regression tests for the 30-day data-age cutoff in HealthKitDataLogCoordinator.
//
// Anchored queries (HKAnchoredObjectQuery) return any sample newly written to
// HealthKit since the last anchor, regardless of the sample's actual date. A
// source that backfills history (a new Apple Watch pairing, a device restore, a
// third-party app sync) therefore surfaces months- or years-old samples on the
// ongoing (anchor != nil) path, which previously had no date bound at all.

// MARK: - Mocks
// The scripted anchor-query service lives in TestSupport/ScriptedAnchorQueryService.swift.

private actor StubAnchorStore: HealthKitAnchorStoreProtocol {
    private let anchorToReturn: HKQueryAnchor?

    init(anchorToReturn: HKQueryAnchor?) {
        self.anchorToReturn = anchorToReturn
    }

    func saveAnchor(_ anchor: HKQueryAnchor, forKey key: String) throws {}
    func loadAnchor(forKey key: String) throws -> HKQueryAnchor? { anchorToReturn }
}

/// Emits one DataLog per sample, preserving the sample's dates so tests can
/// assert which samples survived the age filter.
private struct EchoNormaliser: HKSampleToDataLogNormaliserProtocol {
    func normalise(_ sample: HKSample, profileId: String?) -> [DataLog] {
        let bpm = HKUnit.count().unitDivided(by: .minute())
        let value = (sample as? HKQuantitySample)?.quantity.doubleValue(for: bpm) ?? 0
        return [
            DataLog(
                profileId: profileId,
                logType: .heart,
                dataType: "heart_rate",
                value: value,
                unit: "bpm",
                source: "test",
                recordingMethod: .unknown,
                deviceType: "test",
                startDate: sample.startDate,
                endDate: sample.endDate
            )
        ]
    }
}

private actor SpyDataLogPipeline: DataLogPipelineProtocol {
    private(set) var ingested: [DataLog] = []

    func ingest(_ log: DataLog) async { ingested.append(log) }
    func ingest(_ logs: [DataLog]) async { ingested.append(contentsOf: logs) }
}

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

// MARK: - Helpers

private func heartRateSample(_ value: Double, daysAgo: Double) -> HKQuantitySample {
    let type = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    let bpm = HKUnit.count().unitDivided(by: .minute())
    let date = Date().addingTimeInterval(-daysAgo * 24 * 3600)
    return HKQuantitySample(type: type, quantity: HKQuantity(unit: bpm, doubleValue: value), start: date, end: date)
}

private func makeCoordinator(
    anchorQuery: ScriptedAnchorQueryService,
    anchorStore: StubAnchorStore,
    pipeline: SpyDataLogPipeline
) -> HealthKitDataLogCoordinator {
    HealthKitDataLogCoordinator(
        observerService: NoopObserverService(),
        anchorQueryService: anchorQuery,
        anchorStore: anchorStore,
        normaliser: EchoNormaliser(),
        profileIdProvider: StubProfileIdProvider(),
        dataLogPipeline: pipeline,
        circuitBreaker: nil,
        logger: NoopErrorLogger()
    )
}

// MARK: - Tests

@Test("DataLog coordinator drops samples older than 30 days on the ongoing anchored run")
func testOngoingRunFiltersBackdatedSamples() async throws {
    // 2 recent samples (< 30 days) + 3 backdated samples (> 30 days, like the
    // 2025 reports), returned in one batch, then an empty batch to stop paging.
    let recent = [heartRateSample(70, daysAgo: 1), heartRateSample(72, daysAgo: 10)]
    let backdated = [
        heartRateSample(80, daysAgo: 60),
        heartRateSample(81, daysAgo: 200),
        heartRateSample(82, daysAgo: 260),
    ]
    let anchorQuery = ScriptedAnchorQueryService(batches: [
        (recent + backdated, HKQueryAnchor(fromValue: 99)),
        ([], nil),
    ])
    // A stored (non-nil) anchor selects the ongoing path: the query runs with no
    // date predicate, so the in-code age filter is the only thing guarding it.
    let anchorStore = StubAnchorStore(anchorToReturn: HKQueryAnchor(fromValue: 1))
    let pipeline = SpyDataLogPipeline()
    let coordinator = makeCoordinator(anchorQuery: anchorQuery, anchorStore: anchorStore, pipeline: pipeline)

    let results = await coordinator.querySensors([.heart_rate])

    let result = try #require(results.first { $0.sensor == .heart_rate })
    // All 5 raw samples are fetched — the anchor advances past the old data so it
    // is never re-queried — but only the 2 recent samples produce logs.
    #expect(result.samplesFetched == 5)
    #expect(result.logsProduced == 2)

    let ingested = await pipeline.ingested
    #expect(ingested.count == 2)
    let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
    #expect(ingested.allSatisfy { $0.endDate >= cutoff })
    #expect(Set(ingested.map(\.value)) == [70, 72])

    // The ongoing run does not constrain the query itself by date.
    #expect((anchorQuery.capturedPredicates.first ?? nil) == nil)
}

@Test("DataLog coordinator bounds the initial-sync query with a 30-day date predicate")
func testInitialSyncQueryIsDateBounded() async throws {
    let anchorQuery = ScriptedAnchorQueryService(batches: [([], nil)])
    // No stored anchor selects the first-run path.
    let anchorStore = StubAnchorStore(anchorToReturn: nil)
    let coordinator = makeCoordinator(
        anchorQuery: anchorQuery,
        anchorStore: anchorStore,
        pipeline: SpyDataLogPipeline()
    )

    _ = await coordinator.querySensors([.heart_rate])

    // On first sync the query carries a predicate so HealthKit filters
    // server-side rather than loading years of history into memory.
    #expect((anchorQuery.capturedPredicates.first ?? nil) != nil)
}
