import Foundation
import HealthKit

protocol SleepStatsProvider: Sendable {
    func getStats(from startDate: Date, to endDate: Date, periodicity: Periodicity) async throws -> [SahhaStat]
}

final class SleepStatsProviderImpl: SleepStatsProvider {
    private let authorizationManager: HKAuthorizationManager
    private let sampleQueryHandler: HKSampleQueryHandler

    init(
        authorizationManager: HKAuthorizationManager,
        sampleQueryHandler: HKSampleQueryHandler
    ) {
        self.authorizationManager = authorizationManager
        self.sampleQueryHandler = sampleQueryHandler
    }

    func getStats(
        from startDate: Date,
        to endDate: Date,
        periodicity: Periodicity
    ) async throws -> [SahhaStat] {
        guard let metadata = SensorMapper.metadata(for: .sleep),
            let sleepType = metadata.hkObjectType as? HKCategoryType
        else { throw SensorError.samplesUnavailable(.sleep) }

        guard try await authorizationManager.isAuthorized(for: sleepType)
        else { throw SensorError.permissionDenied(.sleep) }

        // 2. Anchor “sleep day” → 6 PM - 6 PM
        let calendar = Calendar.current
        var anchoredStart = calendar.date(byAdding: .day, value: -1, to: startDate)!
        anchoredStart = calendar.startOfDay(for: anchoredStart)
        anchoredStart = calendar.date(bySetting: .hour, value: 18, of: anchoredStart)!

        var anchoredEnd = calendar.startOfDay(for: endDate)
        anchoredEnd = calendar.date(bySetting: .hour, value: 18, of: anchoredEnd)!

        let predicate = HKQuery.predicateForSamples(withStart: anchoredStart, end: anchoredEnd)

        let rawSamples =
            try await sampleQueryHandler.fetchSamples(
                for: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) as? [HKCategorySample] ?? []

        guard !rawSamples.isEmpty else { return [] }

        enum SleepMetric: String {
            case sleep_duration, sleep_unknown_duration, sleep_in_bed_duration,
                sleep_awake_duration, sleep_rem_duration, sleep_light_duration,
                sleep_deep_duration, sleep_interruptions
        }

        var resultStats: [SahhaStat] = []

        for windowInterval in calendar.rollingWindows(
            from: anchoredStart,
            to: anchoredEnd,
            duration: periodicity.windowDuration
        ) {

            var accumulator = StatSegmentAccumulator<SleepMetric>()

            for sample in rawSamples {
                guard
                    let sliceInterval = DateInterval(
                        start: sample.startDate,
                        end: sample.endDate
                    ).intersection(with: windowInterval)
                else { continue }

                let sourceID = sample.sourceRevision.source.bundleIdentifier
                let minutes = sliceInterval.duration / 60
                let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)

                func add(_ metric: SleepMetric, _ val: Double = minutes) {
                    accumulator.insert(metric, source: sourceID, value: val)
                }

                switch value {
                case .inBed: add(.sleep_in_bed_duration)
                case .awake:
                    add(.sleep_awake_duration)
                    add(.sleep_interruptions, 1)  // interruptions are counts
                default:
                    add(.sleep_duration)
                    if #available(iOS 16.0, *) {
                        switch value {
                        case .asleepREM: add(.sleep_rem_duration)
                        case .asleepCore: add(.sleep_light_duration)
                        case .asleepDeep: add(.sleep_deep_duration)
                        case .asleepUnspecified: add(.sleep_unknown_duration)
                        default: break
                        }
                    } else {
                        add(.sleep_unknown_duration)
                    }
                }
            }

            for (metric, bySource) in accumulator.segments {
                for (sourceID, value) in bySource {
                    resultStats.append(
                        SahhaStat(
                            category: metadata.biomarkerCategory.rawValue,
                            type: metric.rawValue,
                            aggregation: Aggregation.sum.rawValue,
                            periodicity: periodicity.rawValue,
                            value: value.rounded(toPlaces: 4),
                            unit: metadata.unitString,
                            startDateTime: windowInterval.start,
                            endDateTime: windowInterval.end,
                            sources: [sourceID]
                        )
                    )
                }
            }
        }
        return resultStats.sorted { $0 < $1 }
    }
}
