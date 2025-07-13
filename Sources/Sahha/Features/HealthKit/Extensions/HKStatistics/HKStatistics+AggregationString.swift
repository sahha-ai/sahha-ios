import HealthKit

extension HKStatistics {
    var aggregationString: String {
        switch quantityType.aggregationStyle {
        case .cumulative, .discreteEquivalentContinuousLevel:
            return "sum"
        case .discrete, .discreteArithmetic, .discreteTemporallyWeighted:
            return "avg"
        @unknown default:
            return "unknown"
        }
    }
}
