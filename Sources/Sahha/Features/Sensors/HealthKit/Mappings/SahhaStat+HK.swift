import HealthKit

extension SahhaStat {
    static func build(from statistics: HKStatistics, periodicity: StatPeriodicity = .daily) -> SahhaStat? {
        guard
            let sensor = statistics.quantityType.sahhaSensor,
            let unit = sensor.hkUnit
        else { return nil }

        let value = statistics.aggregatedValue(for: unit).rounded(toPlaces: 4)
        let aggregation = statistics.aggregation
        let srcs = statistics.sources?.map(\.bundleIdentifier) ?? []

        return SahhaStat(
            category: sensor.category.rawValue,
            type: sensor.rawValue,
            aggregation: aggregation.rawValue,
            periodicity: periodicity.rawValue,
            value: value,
            unit: sensor.unitString,
            startDateTime: statistics.startDate,
            endDateTime: statistics.endDate,
            sources: srcs
        )
    }
}
