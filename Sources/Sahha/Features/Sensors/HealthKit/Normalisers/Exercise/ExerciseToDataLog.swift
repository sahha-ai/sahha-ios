import HealthKit

enum ExerciseToDataLog {
    static func normalise(_ samples: [HKSample], sensor: SahhaSensor) -> [DataLog] {
        guard sensor == .exercise else {
            return []
        }

        return samples.flatMap { sample in
            guard let workout = sample as? HKWorkout else {
                return [DataLog]()
            }

            var properties: [String: String] = [:]
            
            if let distance = workout.totalDistance {
                let value = distance.doubleValue(for: .meter()).rounded(toPlaces: 4)
                properties["total_distance"] = "\(value)"
            }
            
            if let energy = workout.totalEnergyBurned {
                let value = energy.doubleValue(for: .largeCalorie()).rounded(toPlaces: 4)
                properties["total_energy_burned"] = "\(value)"
            }
            
            let additionalProperties = properties.isEmpty ? nil : properties

            let parent = DataLog(
                parentId: nil,
                logType: sensor.logType,
                dataType: "exercise_session_\(workout.workoutActivityType.name)",
                value: 1.0,
                unit: sensor.unitString,
                source: workout.sourceId,
                recordingMethod: workout.recordingMethod,
                deviceType: workout.deviceType,
                startDate: workout.startDate,
                endDate: workout.endDate,
                additionalProperties: additionalProperties
            )

            var logs: [DataLog] = [parent]
            
            if let workoutEvents = workout.workoutEvents, !workoutEvents.isEmpty {
                logs.append(
                    contentsOf: workoutEvents.compactMap { event in
                        DataLog(
                            parentId: parent.id,
                            logType: sensor.logType,
                            dataType: "exercise_event_\(event.type.name)",
                            value: 1.0,
                            unit: sensor.unitString,
                            source: workout.sourceId,
                            recordingMethod: workout.recordingMethod,
                            deviceType: workout.deviceType,
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
                            parentId: parent.id,
                            logType: sensor.logType,
                            dataType: "exercise_segment_\(activity.workoutConfiguration.activityType.name)",
                            value: 1.0,
                            unit: sensor.unitString,
                            source: workout.sourceId,
                            recordingMethod: workout.recordingMethod,
                            deviceType: workout.deviceType,
                            startDate: activity.startDate,
                            endDate: activity.endDate ?? activity.startDate + activity.duration
                        )
                    }
                )
            }

            return logs
        }
    }
}
