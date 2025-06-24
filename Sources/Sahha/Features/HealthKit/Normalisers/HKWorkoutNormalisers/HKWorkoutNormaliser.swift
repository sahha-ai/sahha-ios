import HealthKit

final class HKWorkoutNormaliser: HKNormaliser {
    func normalise(_ sample: HKSample) async -> [any DataLogType] {
        guard let workout = sample as? HKWorkout else {
            return []
        }

        var logs: [DataLog] = []

        let commonData = await extractCommonData(from: sample)

        let workoutLog = DataLog(
            dataType: "exercise_session_" + workout.workoutActivityType.name,
            value: 1.0,
            source: commonData.source,
            recordingMethod: commonData.recordingMethod,
            deviceType: commonData.deviceType,
            startDate: commonData.startDate,
            endDate: commonData.endDate,
            additionalProperties: nil
        )

        let parentId = workoutLog.id.uuidString
        logs.append(workoutLog)

        if let workoutEvents = workout.workoutEvents {
            logs.append(
                contentsOf: workoutEvents.compactMap { event in
                    DataLog(
                        parentId: parentId,
                        dataType: "exercise_event_" + event.description,
                        value: 1.0,
                        source: commonData.source,
                        recordingMethod: commonData.recordingMethod,
                        deviceType: commonData.deviceType,
                        startDate: event.dateInterval.start,
                        endDate: event.dateInterval.end
                    )
                }
            )
        }

        if #available(iOS 16.0, *), !workout.workoutActivities.isEmpty {
            logs.append(
                contentsOf: workout.workoutActivities.compactMap { activity in
                    DataLog(
                        parentId: parentId,
                        dataType: "exercise_segment_"
                            + activity.workoutConfiguration.activityType.name,
                        value: 1.0,
                        source: commonData.source,
                        recordingMethod: commonData.recordingMethod,
                        deviceType: commonData.deviceType,
                        startDate: activity.startDate,
                        endDate: activity.endDate ?? activity.startDate
                            + activity.duration
                    )
                }
            )
        }

        return logs
    }
}
