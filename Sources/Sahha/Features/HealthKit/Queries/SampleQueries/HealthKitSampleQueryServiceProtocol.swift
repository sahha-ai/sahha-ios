import HealthKit

protocol HealthKitSampleQueryServiceProtocol: Sendable {
    func runSampleQuery(
        for sampleType: HKSampleType,
        predicate: NSPredicate?,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?,
    ) async throws -> [HKSample]
}

extension HealthKitSampleQueryServiceProtocol {
    public func runSampleQuery(
        for sampleType: HKSampleType,
        predicate: NSPredicate? = nil,
        limit: Int = HKObjectQueryNoLimit,
        sortDescriptors: [NSSortDescriptor]? = nil
    ) async throws -> [HKSample] {
        try await runSampleQuery(
            for: sampleType,
            predicate: predicate,
            limit: limit,
            sortDescriptors: sortDescriptors
        )
    }
}
