import HealthKit

protocol HKStatisticsQueryHandler: Actor {
    func executeQuery(for quantityType: HKQuantityType, startDateTime: Date, endDateTime: Date) async throws -> [HKStatistics]
}

final actor HKStatisticsQueryHandlerImpl: HKStatisticsQueryHandler {
    private let healthStore: HKHealthStore
    private let logger: Logger

    init(healthStore: HKHealthStore = HKHealthStore(), logger: Logger) {
        self.healthStore = healthStore
        self.logger = logger
    }

    func executeQuery(for quantityType: HKQuantityType, startDateTime: Date, endDateTime: Date) async throws -> [HKStatistics] {
        let stats: [HKStatistics] = try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: nil,
                options: .cumulativeSum,
                anchorDate: Date(),
                intervalComponents: DateComponents()
            )
            query.initialResultsHandler = { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: results?.statistics() ?? [])
                }
            }
            healthStore.execute(query)
        }
        
        return stats
    }
}
