import HealthKit

enum WorkoutToDataLog {
    static let normalise: NormalisingEngine<HKSample, DataLog>.Normaliser = { sample in
        guard let sample = sample as? HKWorkout,
            let sensor = SahhaSensor.sensor(for: sample.sampleType),
            sensor == .exercise
        else { return [] }

        let extractor = WorkoutPropertiesExtractor()
        let additionalProperties = extractor.extract(from: sample)

        let parent = DataLog(
            parentId: nil,
            logType: sensor.logType,
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

        var logs: [DataLog] = [parent]

        if let workoutEvents = sample.workoutEvents, !workoutEvents.isEmpty {
            logs.append(
                contentsOf: workoutEvents.compactMap { event in
                    DataLog(
                        parentId: parent.id,
                        logType: sensor.logType,
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
                        logType: sensor.logType,
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
