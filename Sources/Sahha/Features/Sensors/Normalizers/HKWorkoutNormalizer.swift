import Foundation
import HealthKit

class HKWorkoutNormalizer: HKSampleNormalizer {
    func normalize(_ sample: HKSample, source: String, deviceType: String, recordingMethod: DataLogRecordingMethod, startDate: Date, endDate: Date) -> [DataLog]? {
        guard let workout = sample as? HKWorkout else { return nil }
        var logs: [DataLog] = []
        
        let workoutLog = DataLog(
            dataType: "exercise_session_" + workout.workoutActivityType.name,
            value: 1.0,
            source: source,
            recordingMethod: recordingMethod,
            deviceType: deviceType,
            startDate: startDate,
            endDate: endDate,
            additionalProperties: nil
        )
        
        let parentId = workoutLog.id.uuidString
        logs.append(workoutLog)
        
        if let workoutEvents = workout.workoutEvents {
            logs.append(contentsOf: workoutEvents.compactMap { event in
                DataLog(
                    parentId: parentId,
                    dataType: "exercise_event_" + event.description,
                    value: 1.0,
                    source: source,
                    recordingMethod: recordingMethod,
                    deviceType: deviceType,
                    startDate: event.dateInterval.start,
                    endDate: event.dateInterval.end
                )
            })
        }
        
        if #available(iOS 16.0, *), !workout.workoutActivities.isEmpty {
            logs.append(contentsOf: workout.workoutActivities.compactMap { activity in
                DataLog(
                    parentId: parentId,
                    dataType: "exercise_segment_" + activity.workoutConfiguration.activityType.name,
                    value: 1.0,
                    source: source,
                    recordingMethod: recordingMethod,
                    deviceType: deviceType,
                    startDate: activity.startDate,
                    endDate: activity.endDate ?? activity.startDate + activity.duration
                )
            })
        }
        
        return logs
    }
}
}
