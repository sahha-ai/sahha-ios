import HealthKit

extension SahhaStat {
    static func create(from stat: HKStatistics) -> SahhaStat? {
        guard let sensor = SahhaSensor.sensor(for: stat.quantityType), let unit = sensor.hkUnit else { return nil }

        let value = stat.aggregatedValue(for: unit)
        let sources = (stat.sources ?? []).map { $0.bundleIdentifier }
        
        return SahhaStat(
            category: sensor.biomarkerCategory.rawValue,
            type: sensor.rawValue,
            aggregation: stat.aggregationString,
            periodicity: "daily", // TODO: Currently only daily periodicity supported
            value: value.rounded(toPlaces: 4),
            unit: sensor.unitString,
            startDateTime: stat.startDate,
            endDateTime: stat.endDate,
            sources: sources
        )
    }
}
