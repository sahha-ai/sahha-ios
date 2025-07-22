import HealthKit

enum HKAsyncSampleQuery {
    static func execute(
        for sampleType: HKSampleType,
        predicate: NSPredicate? = nil,
        limit: Int = HKObjectQueryNoLimit,
        sortDescriptors: [NSSortDescriptor]? = nil,
        using healthStore: HKHealthStore
    ) async throws -> [HKSample] {
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: limit,
                sortDescriptors: sortDescriptors
            ) { _, samplesOrNil, errorOrNil in
                if let error = errorOrNil {
                    continuation.resume(throwing: error)
                } else {
                    let samples = samplesOrNil ?? []
                    continuation.resume(returning: samples)
                }
            }
            healthStore.execute(query)
        }
    }
}
