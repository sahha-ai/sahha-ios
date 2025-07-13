import HealthKit

extension HKStatistics {
    func aggregatedValue(for unit: HKUnit) -> Double {
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
