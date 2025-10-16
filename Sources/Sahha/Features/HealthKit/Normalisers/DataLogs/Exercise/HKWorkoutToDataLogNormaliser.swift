import HealthKit

final class HKWorkoutToDataLogNormaliser: HKSampleToDataLogNormaliserProtocol {
    func normalise(_ sample: HKSample) -> [DataLog] {
        guard let sample = sample as? HKWorkout,
            let sensor = HKWorkoutType.workoutType().sahhaSensor,
            sensor == .exercise
        else { return [] }

        var properties: [String: String] = [:]

        if let distance = sample.totalDistance {
            let value = distance.doubleValue(for: .meter()).rounded(toPlaces: 4)
            properties["total_distance"] = "\(value)"
        }

        if let energy = sample.totalEnergyBurned {
            let value = energy.doubleValue(for: .largeCalorie()).rounded(toPlaces: 4)
            properties["total_energy_burned"] = "\(value)"
        }

        let additionalProperties: [String: String]? = properties.isEmpty ? nil : properties

        let parent = DataLog(
            logType: sensor.dataLogType,
            dataType: "exercise_session_\(sample.workoutActivityType.name)",
            value: 1.0,
            unit: sensor.unitString,
            source: sample.sourceId,
            recordingMethod: sample.recordingMethod,
            deviceType: sample.deviceType,
            startDate: sample.startDate,
            endDate: sample.endDate,
            additionalProperties: additionalProperties
        )

        var logs = [parent]

        if let workoutEvents = sample.workoutEvents, !workoutEvents.isEmpty {
            logs.append(
                contentsOf: workoutEvents.compactMap { event in
                    DataLog(
                        parentId: parent.id,
                        logType: sensor.dataLogType,
                        dataType: "exercise_event_\(event.type.name)",
                        value: 1.0,
                        unit: sensor.unitString,
                        source: sample.sourceId,
                        recordingMethod: sample.recordingMethod,
                        deviceType: sample.deviceType,
                        startDate: event.dateInterval.start,
                        endDate: event.dateInterval.end
                    )
                }
            )
        }

        if #available(iOS 16.0, *), !sample.workoutActivities.isEmpty {
            logs.append(
                contentsOf: sample.workoutActivities.compactMap { activity in
                    DataLog(
                        parentId: parent.id,
                        logType: sensor.dataLogType,
                        dataType: "exercise_segment_\(activity.workoutConfiguration.activityType.name)",
                        value: 1.0,
                        unit: sensor.unitString,
                        source: sample.sourceId,
                        recordingMethod: sample.recordingMethod,
                        deviceType: sample.deviceType,
                        startDate: activity.startDate,
                        endDate: activity.endDate ?? activity.startDate + activity.duration
                    )
                }
            )
        }

        return logs
    }
}
