import HealthKit

extension SahhaStat {
    static func create(from stat: HKStatistics) -> SahhaStat? {
        guard let metadata = SensorMapper.metadata(for: stat.quantityType), let unit = metadata.hkUnit else { return nil }

        let value = stat.aggregatedValue(for: unit)
        let sources = (stat.sources ?? []).map { $0.bundleIdentifier }
        
        return SahhaStat(
            category: metadata.biomarkerCategory.rawValue,
            type: metadata.sensor.rawValue,
            aggregation: stat.aggregationString,
            periodicity: "daily", // TODO: Currently only daily periodicity supported
            value: value.rounded(toPlaces: 4),
            unit: metadata.unitString,
            startDateTime: stat.startDate,
            endDateTime: stat.endDate,
            sources: sources
        )
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
        case .cumulative, .discreteEquivalentContinuousLevel:
            return "sum"
        case .discrete, .discreteArithmetic, .discreteTemporallyWeighted:
            return "avg"
        @unknown default:
            return "unknown"
        }
    }
}

