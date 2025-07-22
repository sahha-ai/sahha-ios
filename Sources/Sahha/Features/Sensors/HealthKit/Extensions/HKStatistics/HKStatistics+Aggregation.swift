import HealthKit

extension HKStatistics {
    var aggregation: StatAggregation {
        switch quantityType.aggregationStyle {
        case .cumulative, .discreteEquivalentContinuousLevel:
            return .sum
        case .discrete, .discreteArithmetic, .discreteTemporallyWeighted:
            return .avg
        @unknown default:
            return .sum
        }
    }
}

