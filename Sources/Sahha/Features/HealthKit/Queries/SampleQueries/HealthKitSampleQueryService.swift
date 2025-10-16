import HealthKit

final class HealthKitSampleQueryService: HealthKitSampleQueryServiceProtocol {
    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore = .init()) {
        self.healthStore = healthStore
    }

    func runSampleQuery(
        for sampleType: HKSampleType,
        predicate: NSPredicate?,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
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
