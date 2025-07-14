import HealthKit

protocol HKAnchorQueryHandler: Sendable {
    func fetchAnchoredUpdates(
        for sampleType: HKSampleType,
        predicate: NSPredicate?,
        limit: Int
    ) async throws -> (samples: [HKSample], newAnchor: HKQueryAnchor?)
}

final class HKAnchorQueryHandlerImpl: HKAnchorQueryHandler {
    private let healthStore: HKHealthStore
    private let anchorStore: HKAnchorStore
    
    init(healthStore: HKHealthStore = HKHealthStore(), anchorStore: HKAnchorStore) {
        self.healthStore = healthStore
        self.anchorStore = anchorStore
    }
    
    func fetchAnchoredUpdates(
        for sampleType: HKSampleType,
        predicate: NSPredicate? = nil,
        limit: Int = HKObjectQueryNoLimit
    ) async throws -> (samples: [HKSample], newAnchor: HKQueryAnchor?) {
        let anchor = await anchorStore.getAnchor(for: sampleType.identifier)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: sampleType,
                predicate: predicate,
                anchor: anchor,
                limit: limit
            ) { _, samples, _, newAnchor, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples ?? [], newAnchor))
            }
            
            healthStore.execute(query)
        }
    }
}
