import Foundation
import HealthKit

protocol ExerciseStatsProvider: Sendable {
    func getStats(from startDate: Date, to endDate: Date, periodicity: Periodicity) async throws -> [SahhaStat]
}

final class ExerciseStatsProviderImpl: ExerciseStatsProvider {
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

        guard let metadata = SensorMapper.metadata(for: .exercise) else {
            throw SensorError.samplesUnavailable(.exercise)
        }

        let workoutType = HKWorkoutType.workoutType()

        guard try await authorizationManager.isAuthorized(for: workoutType) else {
            throw SensorError.permissionDenied(.exercise)
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)

        let workouts =
            try await sampleQueryHandler.fetchSamples(
                for: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) as? [HKWorkout] ?? []

        guard !workouts.isEmpty else { return [] }

        var resultStats: [SahhaStat] = []
        let calendar = Calendar.current

        for windowInterval in calendar.rollingWindows(
            from: startDate,
            to: endDate,
            duration: periodicity.windowDuration
        ) {

            var accumulator = StatSegmentAccumulator<String>()

            for workout in workouts {
                guard
                    let sliceInterval = DateInterval(
                        start: workout.startDate,
                        end: workout.endDate
                    ).intersection(with: windowInterval)
                else { continue }

                let sourceID = workout.sourceRevision.source.bundleIdentifier
                let minutes = sliceInterval.duration / 60

                accumulator.insert("workout_duration", source: sourceID, value: minutes)
                let activityKey = "workout_\(workout.workoutActivityType.name)_duration"
                accumulator.insert(activityKey, source: sourceID, value: minutes)
            }

            for (metricKey, bySource) in accumulator.segments {
                for (sourceID, value) in bySource {
                    resultStats.append(
                        SahhaStat(
                            category: metadata.biomarkerCategory.rawValue,
                            type: metricKey,
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
