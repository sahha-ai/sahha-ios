import HealthKit

final class HealthKitAnchorQueryService: HealthKitAnchorQueryServiceProtocol {
    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore = .init()) {
        self.healthStore = healthStore
    }

    func runAnchorQuery(
        for sampleType: HKSampleType,
        predicate: NSPredicate?,
        anchor: HKQueryAnchor?,
        limit: Int
    ) async throws -> ([HKSample], HKQueryAnchor?) {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: sampleType,
                predicate: predicate,
                anchor: anchor,
                limit: limit
            ) { _, samplesOrNil, _, newAnchor, errorOrNil in
                if let error = errorOrNil {
                    continuation.resume(throwing: error)
                } else {
                    let samples = samplesOrNil ?? []
                    continuation.resume(returning: (samples, newAnchor))
                }
            }
            healthStore.execute(query)
        }
    }
}
