import HealthKit

extension HKAnchoredObjectQuery {
    static func anchoredQuery(
        for sampleType: HKSampleType,
        predicate: NSPredicate? = nil,
        anchor: HKQueryAnchor? = nil,
        limit: Int = HKObjectQueryNoLimit,
        using healthStore: HKHealthStore
    ) async throws -> (samples: [HKSample], newAnchor: HKQueryAnchor?) {
        return try await withCheckedThrowingContinuation { continuation in
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
