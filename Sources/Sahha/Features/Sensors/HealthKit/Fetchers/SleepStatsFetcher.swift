import HealthKit

class SleepStatsFetcher {
    private let periodicity: StatPeriodicity
    private let healthStore: HKHealthStore

    init(periodicity: StatPeriodicity = .daily, healthStore: HKHealthStore = .init()) {
        self.periodicity = periodicity
        self.healthStore = healthStore
    }

    func fetch(startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthKitUnavailable
        }

        var start = Calendar.current.date(byAdding: .day, value: -1, to: startDateTime) ?? startDateTime
        start = Calendar.current.startOfDay(for: start)
        start = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: start) ?? start
        var end = Calendar.current.startOfDay(for: endDateTime)
        end = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: end) ?? end

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        let samples = try await HKSampleQuery.sampleQuery(
            for: HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!,
            predicate: predicate,
            using: healthStore
        ) as? [HKCategorySample] ?? []

        guard !samples.isEmpty else {
            throw HealthKitError.noStatsFound(.sleep)
        }

        let duration: Double = periodicity == .daily ? 86400 : 3600
        var rollingInterval = DateInterval(start: start, duration: duration)
        var stats: [SahhaStat] = []

        while rollingInterval.end <= end {
            var accumulator = StatSegmentAccumulator<SleepAggregate>()

            for sample in samples {
                let sampleInterval = DateInterval(start: sample.startDate, end: sample.endDate)

                if let intersection = sampleInterval.intersection(with: rollingInterval) {
                    let source = sample.sourceRevision.source.bundleIdentifier
                    let value = intersection.duration / 60.0

                    switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
                    case .inBed:
                        accumulator.insert(.sleep_in_bed_duration, source: source, value: value)
                    case .asleep, .asleepREM, .asleepCore, .asleepDeep, .asleepUnspecified:
                        accumulator.insert(.sleep_duration, source: source, value: value)
                        if #available(iOS 16.0, *) {
                            switch sample.value {
                            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                                accumulator.insert(.sleep_rem_duration, source: source, value: value)
                            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                                accumulator.insert(.sleep_light_duration, source: source, value: value)
                            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                                accumulator.insert(.sleep_deep_duration, source: source, value: value)
                            default:
                                accumulator.insert(.sleep_unknown_duration, source: source, value: value)
                            }
                        }
                    case .awake:
                        accumulator.insert(.sleep_awake_duration, source: source, value: value)
                        accumulator.insert(.sleep_interruptions, source: source, value: 1.0)
                    default:
                        accumulator.insert(.sleep_unknown_duration, source: source, value: value)
                    }
                }
            }

            stats.append(contentsOf: accumulator.segments.flatMap { stage, sources in
                sources.map { source, value in
                    SahhaStat(
                        category: SahhaBiomarkerCategory.sleep.rawValue,
                        type: stage.rawValue,
                        aggregation: StatAggregation.sum.rawValue,
                        periodicity: periodicity.rawValue,
                        value: value,
                        unit: stage == .sleep_interruptions ? "count" : SahhaSensor.sleep.unitString,
                        startDateTime: rollingInterval.start,
                        endDateTime: rollingInterval.end,
                        sources: [source]
                    )
                }
            })

            rollingInterval = DateInterval(start: rollingInterval.end, duration: duration)
        }

        return stats
    }
}
