import HealthKit

extension SahhaStat {
    static func fromHKStatistics(
        _ stat: HKStatistics,
        periodicity: StatPeriodicity = .daily
    ) -> SahhaStat? {
        guard let sensor = stat.quantityType.sahhaSensor, let unit = sensor.hkUnit else { return nil }
        
        let value = stat.aggregatedValue(for: unit).rounded(toPlaces: 4)
        let aggregation = stat.aggregation
        let srcs = stat.sources?.map(\.bundleIdentifier) ?? []
        
        return SahhaStat(
            category: sensor.category.rawValue,
            type: sensor.rawValue,
            aggregation: aggregation.rawValue,
            periodicity: periodicity.rawValue,
            value: value,
            unit: sensor.unitString,
            startDateTime: stat.startDate,
            endDateTime: stat.endDate,
            sources: srcs
        )
    }

    static func fromSleepAggregate(
        stage: SleepAggregate,
        source: String,
        value: Double,
        periodicity: StatPeriodicity,
        interval: DateInterval
    ) -> SahhaStat {
        SahhaStat(
            category: SahhaBiomarkerCategory.sleep.rawValue,
            type: stage.rawValue,
            aggregation: StatAggregation.sum.rawValue,
            periodicity: periodicity.rawValue,
            value: value,
            unit: stage == .sleep_interruptions ? "count" : SahhaSensor.sleep.unitString,
            startDateTime: interval.start,
            endDateTime: interval.end,
            sources: [source]
        )
    }

    static func fromExerciseAggregate(
        type: String,
        source: String,
        value: Double,
        interval: DateInterval
    ) -> SahhaStat {
        SahhaStat(
            category: SahhaBiomarkerCategory.exercise.rawValue,
            type: type,
            aggregation: StatAggregation.sum.rawValue,
            periodicity: StatPeriodicity.daily.rawValue,
            value: value,
            unit: SahhaSensor.exercise.unitString,
            startDateTime: interval.start,
            endDateTime: interval.end,
            sources: [source]
        )
    }
}
