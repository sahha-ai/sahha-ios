import Foundation
import HealthKit

protocol QuantityStatsProvider: Sendable {
    func getStats(
        for sensor: SahhaSensor,
        startDateTime: Date,
        endDateTime: Date,
        periodicity: Periodicity
    ) async throws -> [SahhaStat]
}

final class QuantityStatsProviderImpl: QuantityStatsProvider {
    private let authorizationManager: HKAuthorizationManager
    private let statisticsQueryHandler: HKStatisticsQueryHandler

    init(
        authorizationManager: HKAuthorizationManager,
        statisticsQueryHandler: HKStatisticsQueryHandler
    ) {
        self.authorizationManager = authorizationManager
        self.statisticsQueryHandler = statisticsQueryHandler
    }

    func getStats(
        for sensor: SahhaSensor,
        startDateTime: Date,
        endDateTime: Date,
        periodicity: Periodicity
    ) async throws -> [SahhaStat] {

        guard let metadata = SensorMapper.metadata(for: sensor),
            let quantityType = metadata.hkObjectType as? HKQuantityType
        else { throw SensorError.samplesUnavailable(sensor) }

        guard try await authorizationManager.isAuthorized(for: quantityType)
        else { throw SensorError.permissionDenied(sensor) }

        let calendar = Calendar.current
        let anchor = calendar.startOfDay(for: startDateTime)
        var interval = DateComponents()
        interval.day = periodicity == .daily ? 1 : 0
        interval.hour = periodicity == .hourly ? 1 : 0

        let predicate = HKQuery.predicateForSamples(withStart: anchor, end: endDateTime)

        guard
            let collection = try await statisticsQueryHandler.fetchStatisticsCollection(
                for: quantityType,
                quantitySamplePredicate: predicate,
                options: metadata.statsOptions,
                anchorDate: anchor,
                intervalComponents: interval
            )
        else { return [] }

        var stats: [SahhaStat] = []

        for statistics in collection.statistics() {

            let aggregatedValue = statistics.aggregatedValue(for: metadata.hkUnit!)
            let sourceIDs = (statistics.sources ?? [])
                .map { $0.bundleIdentifier }

            stats.append(
                SahhaStat(
                    category: metadata.biomarkerCategory.rawValue,
                    type: sensor.rawValue,
                    aggregation: statistics.aggregationString,
                    periodicity: periodicity.rawValue,
                    value: aggregatedValue.rounded(toPlaces: 4),
                    unit: metadata.unitString,
                    startDateTime: statistics.startDate,
                    endDateTime: statistics.endDate,
                    sources: sourceIDs
                )
            )
        }
        return stats.sorted { $0 > $1 }
    }
}

extension HKStatistics {

    fileprivate func aggregatedValue(for unit: HKUnit) -> Double {
        switch quantityType.aggregationStyle {
        case .cumulative, .discreteEquivalentContinuousLevel:
            return sumQuantity()?.doubleValue(for: unit) ?? 0.0
        case .discrete, .discreteArithmetic, .discreteTemporallyWeighted:
            return averageQuantity()?.doubleValue(for: unit) ?? 0.0
        @unknown default:
            return 0.0
        }
    }

    fileprivate var aggregationString: String {
        switch quantityType.aggregationStyle {
        case .cumulative, .discreteEquivalentContinuousLevel: return "sum"
        case .discrete, .discreteArithmetic, .discreteTemporallyWeighted: return "avg"
        @unknown default: return "unknown"
        }
    }
}
