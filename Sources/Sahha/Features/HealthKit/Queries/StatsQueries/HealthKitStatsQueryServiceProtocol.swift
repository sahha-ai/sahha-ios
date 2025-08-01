import HealthKit

protocol HealthKitStatsQueryServiceProtocol: Sendable {
    func runStatsQuery(
        for quantityType: HKQuantityType,
        predicate: NSPredicate?,
        options: HKStatisticsOptions,
        anchorDate: Date,
        interval: DateComponents
    ) async throws -> HKStatisticsCollection?
}

extension HealthKitStatsQueryServiceProtocol {
    func runStatsQuery(
        for quantityType: HKQuantityType,
        predicate: NSPredicate? = nil,
        options: HKStatisticsOptions,
        anchorDate: Date,
        interval: DateComponents
    ) async throws -> HKStatisticsCollection? {
        try await runStatsQuery(
            for: quantityType,
            predicate: predicate,
            options: options,
            anchorDate: anchorDate,
            interval: interval
        )
    }
}
