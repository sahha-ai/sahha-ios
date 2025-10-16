import HealthKit

extension HKStatistics {
    var aggregationType: AggregationType {
        switch quantityType.aggregationStyle {
        case .cumulative, .discreteEquivalentContinuousLevel:
            return .sum
        case .discrete, .discreteArithmetic, .discreteTemporallyWeighted:
            return .avg
        @unknown default:
            return .sum
        }
    }
    
    func aggregationValue(for unit: HKUnit) -> Double {
        switch quantityType.aggregationStyle {
        case .cumulative, .discreteEquivalentContinuousLevel:
            return sumQuantity()?.doubleValue(for: unit) ?? 0.0
        case .discrete, .discreteArithmetic, .discreteTemporallyWeighted:
            return averageQuantity()?.doubleValue(for: unit) ?? 0.0
        @unknown default:
            return 0.0
        }
    }
}

