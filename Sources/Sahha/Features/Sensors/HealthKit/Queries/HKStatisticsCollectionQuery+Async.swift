import HealthKit

extension HKStatisticsCollectionQuery {
    static func statisticsQuery(
        for quantityType: HKQuantityType,
        predicate: NSPredicate? = nil,
        options: HKStatisticsOptions,
        anchorDate: Date,
        interval: DateComponents,
        using healthStore: HKHealthStore
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
