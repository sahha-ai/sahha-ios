import HealthKit

final class HealthKitStatsQueryService: HealthKitStatsQueryServiceProtocol {
    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore = .init()) {
        self.healthStore = healthStore
    }

    func runStatsQuery(
        for quantityType: HKQuantityType,
        predicate: NSPredicate?,
        options: HKStatisticsOptions,
        anchorDate: Date,
        interval: DateComponents
    ) async throws -> HKStatisticsCollection? {
        try await withCheckedThrowingContinuation { cont in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: anchorDate,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, collection, error in
                if let error = error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: collection)
                }
            }
            healthStore.execute(query)
        }
    }
}
