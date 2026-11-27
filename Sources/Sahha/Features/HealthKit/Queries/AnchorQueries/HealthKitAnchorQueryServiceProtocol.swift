import HealthKit

protocol HealthKitAnchorQueryServiceProtocol: Sendable {
    func runAnchorQuery(
        for sampleType: HKSampleType,
        predicate: NSPredicate?,
        anchor: HKQueryAnchor?,
        limit: Int
    ) async throws -> AnchoredQueryPage
}

extension HealthKitAnchorQueryServiceProtocol {
    func runAnchorQuery(
        for sampleType: HKSampleType,
        predicate: NSPredicate? = nil,
        anchor: HKQueryAnchor? = nil,
        limit: Int = HKObjectQueryNoLimit
    ) async throws -> AnchoredQueryPage {
        try await runAnchorQuery(
            for: sampleType,
            predicate: predicate,
            anchor: anchor,
            limit: limit
        )
    }
}
