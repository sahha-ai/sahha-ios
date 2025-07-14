import HealthKit

protocol HKStatisticsQueryHandler: Sendable {
    func fetchStatisticsCollection(
        for quantityType: HKQuantityType,
        quantitySamplePredicate: NSPredicate?,
        options: HKStatisticsOptions,
        anchorDate: Date,
        intervalComponents: DateComponents
    ) async throws -> HKStatisticsCollection?
}

final class HKStatisticsQueryHandlerImpl: HKStatisticsQueryHandler {
    private let healthStore: HKHealthStore
    
    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }
    
    func fetchStatisticsCollection(
        for quantityType: HKQuantityType,
        quantitySamplePredicate: NSPredicate? = nil,
        options: HKStatisticsOptions = [],
        anchorDate: Date,
        intervalComponents: DateComponents
    ) async throws -> HKStatisticsCollection? {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: quantitySamplePredicate,
                options: options,
                anchorDate: anchorDate,
                intervalComponents: intervalComponents
            )
            
            query.initialResultsHandler = { _, collection, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: collection)
            }
            
            healthStore.execute(query)
        }
    }
}
