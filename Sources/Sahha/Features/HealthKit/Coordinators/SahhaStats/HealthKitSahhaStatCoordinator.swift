import HealthKit

final class HealthKitSahhaStatCoordinator: HealthKitSahhaStatCoordinatorProtocol {
    private let statsQueryService: HealthKitStatsQueryServiceProtocol
    private let sampleQueryService: HealthKitSampleQueryServiceProtocol
    private let permissions: HealthKitPermissionsServiceProtocol
    private let logger: ErrorLoggerProtocol

    init(
        statsQueryService: HealthKitStatsQueryServiceProtocol,
        sampleQueryService: HealthKitSampleQueryServiceProtocol,
        permissions: HealthKitPermissionsServiceProtocol,
        logger: ErrorLoggerProtocol
    ) {
        self.statsQueryService = statsQueryService
        self.sampleQueryService = sampleQueryService
        self.permissions = permissions
        self.logger = logger
    }

    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat] {
        guard startDateTime <= endDateTime else {
            throw SahhaError(message: "Start date time must be less than or equal to end date time.")
        }
        
        switch sensor {
        case .sleep:
            return try await getSleepStats(
                startDateTime: startDateTime,
                endDateTime: endDateTime,
                periodicity: .daily
            )
        case .exercise:
            return try await getExerciseStats(
                startDateTime: startDateTime,
                endDateTime: endDateTime
            )
        default:
            return try await getQuantityStats(
                for: sensor,
                startDateTime: startDateTime,
                endDateTime: endDateTime,
                periodicity: .daily
            )
        }
    }

    // MARK: - Sleep Statistics
    private func getSleepStats(startDateTime: Date, endDateTime: Date, periodicity: Periodicity) async throws -> [SahhaStat] {
        guard try await permissions.hasPermissions(for: .sleep) else {
            throw SahhaError(message: "User permission needed to collect sleep stats.")
        }

        let sampleType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!

        // Align query range to sleep window (6pm to 6pm)
        let start = startDateTime.alignedToSleepWindowStart()
        let end = endDateTime.alignedToSleepWindowEnd()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        var samples: [HKCategorySample]
        do {
            samples = try await sampleQueryService.runSampleQuery(
                for: sampleType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ).compactMap { $0 as? HKCategorySample }
        } catch {
            logger.postError(error)
            throw error
        }

        guard !samples.isEmpty else {
            throw SahhaError(message: "No sleep stats were found for the given date range.")
        }

        var sahhaStats: [SahhaStat] = []
        let intervals = Date.rollingIntervals(from: start, to: end, periodicity: periodicity)

        // Aggregate samples for each interval
        for interval in intervals {
            var aggregator = SegmentAggregator<SleepAggregate>()

            for sample in samples {
                guard let sleepStage = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { continue }
                let sampleInterval = DateInterval(start: sample.startDate, end: sample.endDate)
                guard let intersection = sampleInterval.intersection(with: interval) else { continue }

                let source = sample.sourceRevision.source.bundleIdentifier
                let minutes = intersection.duration / 60.0

                // Group sleep by stage for each source
                if sleepStage == .inBed {
                    aggregator.add(minutes, for: .sleep_in_bed_duration, source: source)
                } else if sleepStage.isAsleep {  // Custom computed var below
                    aggregator.add(minutes, for: .sleep_duration, source: source)
                    switch sleepStage {
                    case .asleepREM: aggregator.add(minutes, for: .sleep_rem_duration, source: source)
                    case .asleepCore: aggregator.add(minutes, for: .sleep_light_duration, source: source)
                    case .asleepDeep: aggregator.add(minutes, for: .sleep_deep_duration, source: source)
                    default: aggregator.add(minutes, for: .sleep_unknown_duration, source: source)
                    }
                } else if sleepStage == .awake {
                    aggregator.add(minutes, for: .sleep_awake_duration, source: source)
                    aggregator.add(1.0, for: .sleep_interruptions, source: source)
                } else {
                    aggregator.add(minutes, for: .sleep_unknown_duration, source: source)
                }
            }
            // Map aggregator to stats
            let statPairs = aggregator.all.flatMap { stage, segments in
                segments.map { (stage, $0) }
            }
            let intervalStats = statPairs.map { (stage, sourceValue) in
                let (source, value) = sourceValue
                return SahhaStat(
                    category: SahhaBiomarkerCategory.sleep.rawValue,
                    type: stage.rawValue,
                    aggregation: AggregationType.sum.rawValue,
                    periodicity: periodicity.rawValue,
                    value: value,
                    unit: stage == .sleep_interruptions ? "count" : SahhaSensor.sleep.unitString,
                    startDateTime: interval.start,
                    endDateTime: interval.end,
                    sources: [source]
                )
            }
            sahhaStats.append(contentsOf: intervalStats)
        }

        return sahhaStats
    }

    // MARK: - Exercise Statistics
    private func getExerciseStats(startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat] {
        guard try await permissions.hasPermissions(for: .exercise) else {
            throw SahhaError(message: "User permission needed to collect exercise stats.")
        }

        let sampleType = HKWorkoutType.workoutType()

        // Align range to full days to match HealthKit's workout session storage
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDateTime)
        var end = calendar.date(byAdding: .day, value: 1, to: endDateTime) ?? endDateTime
        end = calendar.startOfDay(for: end)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        var samples: [HKWorkout]
        do {
            samples = try await sampleQueryService.runSampleQuery(
                for: sampleType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ).compactMap { $0 as? HKWorkout }
        } catch {
            logger.postError(error)
            throw error
        }

        guard !samples.isEmpty else {
            throw SahhaError(message: "No exercise stats were found for the given date range.")
        }

        var sahhaStats: [SahhaStat] = []
        let intervals = Date.rollingIntervals(from: start, to: end, periodicity: .daily)

        // Aggregate workouts by session type and source per interval
        for interval in intervals {
            var aggregator = SegmentAggregator<String>()

            for sample in samples {
                let sampleInterval = DateInterval(start: sample.startDate, end: sample.endDate)
                guard let intersection = sampleInterval.intersection(with: interval) else { continue }
                let source = sample.sourceRevision.source.bundleIdentifier
                let minutes = intersection.duration / 60.0

                // Use both the session and total duration as keys
                let key = "exercise_session_\(sample.workoutActivityType.name)_duration"
                aggregator.add(minutes, for: key, source: source)
                aggregator.add(minutes, for: "exercise_duration", source: source)
            }
            // Map aggregator to stats
            let statPairs = aggregator.all.flatMap { type, segments in
                segments.map { (type, $0) }
            }
            let intervalStats = statPairs.map { (type, sourceValue) in
                let (source, value) = sourceValue
                return SahhaStat(
                    category: SahhaBiomarkerCategory.exercise.rawValue,
                    type: type,
                    aggregation: AggregationType.sum.rawValue,
                    periodicity: Periodicity.daily.rawValue,
                    value: value,
                    unit: SahhaSensor.exercise.unitString,
                    startDateTime: interval.start,
                    endDateTime: interval.end,
                    sources: [source]
                )
            }
            sahhaStats.append(contentsOf: intervalStats)
        }

        return sahhaStats
    }

    // MARK: - Quantity Statistics
    private func getQuantityStats(
        for sensor: SahhaSensor,
        startDateTime: Date,
        endDateTime: Date,
        periodicity: Periodicity
    ) async throws -> [SahhaStat] {
        guard try await permissions.hasPermissions(for: sensor) else {
            throw SahhaError(message: "User permission needed to collect \(sensor.rawValue) stats.")
        }

        guard let quantityType = sensor.hkObjectType as? HKQuantityType else {
            throw SahhaError(message: "Stats are not available for \(sensor.rawValue)")
        }

        let calendar = Calendar.current
        let start: Date
        var end: Date
        var dateComponents = DateComponents()

        // Adjust the date range and interval based on periodicity
        switch periodicity {
        case .daily:
            start = calendar.startOfDay(for: startDateTime)
            end = calendar.date(byAdding: .day, value: 1, to: endDateTime) ?? endDateTime
            end = calendar.startOfDay(for: end)
            dateComponents.day = 1
        case .hourly:
            start = startDateTime
            end = endDateTime
            dateComponents.hour = 1
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        var collection: HKStatisticsCollection?
        do {
            collection = try await statsQueryService.runStatsQuery(
                for: quantityType,
                predicate: predicate,
                options: sensor.statsOptions,
                anchorDate: start,
                interval: dateComponents
            )
        } catch {
            logger.postError(error)
            throw error
        }

        guard let stats = collection?.statistics(), !stats.isEmpty else {
            throw SahhaError(message: "No \(sensor.rawValue) stats were found for the given date range.")
        }

        let sahhaStats: [SahhaStat] = stats.compactMap { stat in
            guard let unit = sensor.hkUnit else { return nil }
            return SahhaStat(
                category: sensor.category.rawValue,
                type: sensor.rawValue,
                aggregation: stat.aggregationType.rawValue,
                periodicity: periodicity.rawValue,
                value: stat.aggregationValue(for: unit).rounded(toPlaces: 4),
                unit: sensor.unitString,
                startDateTime: stat.startDate,
                endDateTime: stat.endDate,
                sources: stat.sources?.map(\.bundleIdentifier) ?? []
            )
        }

        return sahhaStats
    }
}

// MARK: - SegmentAggregator
/// Aggregates numeric values by (key, source) for use in rolling stat calculations.
private struct SegmentAggregator<Key: Hashable> {
    private(set) var data: [Key: [String: Double]] = [:]

    mutating func add(_ value: Double, for key: Key, source: String) {
        data[key, default: [:]][source, default: 0] += value
    }

    subscript(key: Key) -> [String: Double]? {
        data[key]
    }

    var all: [Key: [String: Double]] {
        data
    }
}

// MARK: - Date Helpers
extension Date {
    /// Returns the date aligned to the previous day's 6pm window (18:00).
    fileprivate func alignedToSleepWindowStart() -> Date {
        let calendar = Calendar.current
        var date = calendar.date(byAdding: .day, value: -1, to: self) ?? self
        date = calendar.startOfDay(for: date)
        return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: date) ?? date
    }

    /// Returns the date aligned to the 6pm of this date's day.
    fileprivate func alignedToSleepWindowEnd() -> Date {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: self)
        return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: dayStart) ?? self
    }

    /// Generates rolling intervals (hourly/daily) between two dates.
    fileprivate static func rollingIntervals(
        from start: Date,
        to end: Date,
        periodicity: Periodicity
    ) -> [DateInterval] {
        var intervals: [DateInterval] = []
        var currentStart = start
        let duration: TimeInterval = periodicity == .hourly ? 3600 : 86400

        while currentStart < end {
            let intervalEnd = min(currentStart.addingTimeInterval(duration), end)
            intervals.append(DateInterval(start: currentStart, end: intervalEnd))
            currentStart = intervalEnd
        }
        return intervals
    }
}

// MARK: - Sleep Helpers
private enum SleepAggregate: String, CaseIterable {
    case sleep_duration
    case sleep_unknown_duration
    case sleep_in_bed_duration
    case sleep_awake_duration
    case sleep_rem_duration
    case sleep_light_duration
    case sleep_deep_duration
    case sleep_interruptions
}

extension HKCategoryValueSleepAnalysis {
    /// Returns true if the sleep stage is any type of "asleep".
    fileprivate var isAsleep: Bool {
        if self == .asleep { return true }
        if #available(iOS 16.0, *) {
            switch self {
            case .asleepREM, .asleepCore, .asleepDeep, .asleepUnspecified:
                return true
            default:
                return false
            }
        }
        return false
    }
}

// MARK: - SahhaSensor+StatsOptions
extension SahhaSensor {
    /// Returns the appropriate HKStatisticsOptions for the sensor.
    fileprivate var statsOptions: HKStatisticsOptions {
        return switch self {
        case .heart_rate, .resting_heart_rate, .walking_heart_rate_average, .heart_rate_variability_sdnn, .blood_pressure_systolic,
            .blood_pressure_diastolic, .blood_glucose, .vo2_max, .oxygen_saturation, .respiratory_rate, .sleeping_wrist_temperature,
            .basal_body_temperature, .body_temperature, .basal_metabolic_rate, .height, .weight, .lean_body_mass, .body_mass_index, .body_water_mass,
            .body_fat, .waist_circumference, .walking_speed, .six_minute_walk_test_distance, .walking_asymmetry_percentage,
            .walking_double_support_percentage, .walking_steadiness, .walking_step_length, .stair_ascent_speed, .stair_descent_speed, .running_speed,
            .running_power, .running_ground_contact_time, .running_stride_length, .running_vertical_oscillation:
            .discreteAverage
        default:
            .cumulativeSum
        }
    }
}
