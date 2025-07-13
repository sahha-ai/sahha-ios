import HealthKit

protocol HKSampleQueryHandler: Actor {
    func executeQuery(for sampleType: HKSampleType, startDateTime: Date, endDateTime: Date) async throws -> [HKSample]
}

final actor HKSampleQueryHandlerImpl: HKSampleQueryHandler {
    private let healthStore: HKHealthStore
    private let logger: Logger
    
    init(healthStore: HKHealthStore = HKHealthStore(), logger: Logger) {
        self.healthStore = healthStore
        self.logger = logger
    }
    
    func executeQuery(for sampleType: HKSampleType, startDateTime: Date, endDateTime: Date) async throws -> [HKSample] {
        let predicate = HKQuery.predicateForSamples(withStart: startDateTime, end: endDateTime)
        let startDateDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let samples: [HKSample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [startDateDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }
            healthStore.execute(query)
        }
        
        return samples
    }
}
