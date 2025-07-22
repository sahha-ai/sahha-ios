import HealthKit

class ExerciseStatsFetcher {
    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore = .init()) {
        self.healthStore = healthStore
    }

    func fetch(startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthKitUnavailable
        }

        let start = Calendar.current.startOfDay(for: startDateTime)
        var end = Calendar.current.date(byAdding: .day, value: 1, to: endDateTime) ?? endDateTime
        end = Calendar.current.startOfDay(for: end)

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        let samples = try await HKSampleQuery.sampleQuery(
            for: HKSampleType.workoutType(),
            predicate: predicate,
            using: healthStore
        ) as? [HKWorkout] ?? []

        guard !samples.isEmpty else {
            throw HealthKitError.noStatsFound(.exercise)
        }

        let day: Double = 86400
        var rollingInterval = DateInterval(start: start, duration: day)
        var stats: [SahhaStat] = []

        while rollingInterval.end <= end {
            var accumulator = StatSegmentAccumulator<String>()

            for sample in samples {
                let sampleInterval = DateInterval(start: sample.startDate, end: sample.endDate)

                if let intersection = sampleInterval.intersection(with: rollingInterval) {
                    let source = sample.sourceRevision.source.bundleIdentifier
                    let value = intersection.duration / 60.0

                    let sessionKey = "exercise_session_\(sample.workoutActivityType.name)_duration"
                    accumulator.insert(sessionKey, source: source, value: value)
                    accumulator.insert("exercise_duration", source: source, value: value)
                }
            }

            stats.append(contentsOf: accumulator.segments.flatMap { session, sources in
                sources.map { source, value in
                    SahhaStat(
                        category: SahhaBiomarkerCategory.exercise.rawValue,
                        type: session,
                        aggregation: StatAggregation.sum.rawValue,
                        periodicity: StatPeriodicity.daily.rawValue,
                        value: value,
                        unit: SahhaSensor.exercise.unitString,
                        startDateTime: rollingInterval.start,
                        endDateTime: rollingInterval.end,
                        sources: [source]
                    )
                }
            })

            rollingInterval = DateInterval(start: rollingInterval.end, duration: day)
        }

        return stats
    }
}
