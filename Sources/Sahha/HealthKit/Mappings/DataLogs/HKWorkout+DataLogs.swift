import HealthKit

extension HKWorkout {
    func toDataLogs_internal() -> [DataLog]? {
        let workoutLog = makeWorkoutLog()
        let parentId = workoutLog.generateId().uuidString
        let eventLogs = makeEventLogs(parentId: parentId)
        let activityLogs = makeActivityLogs(parentId: parentId)
        
        let allLogs = [workoutLog] + eventLogs + activityLogs
        return allLogs.isEmpty ? nil : allLogs
    }
    
    private func makeWorkoutLog() -> DataLog {
        DataLog(
            dataType: "exercise_session_" + workoutActivityType.name,
            value: 1.0,
            source: sourceRevision.source.name,
            recordingMethod: recordingMethod,
            deviceType: sourceRevision.productType ?? "unknown",
            startDateTime: startDate,
            endDateTime: endDate,
            additionalProperties: additionalProperties
        )
    }
    
    private var additionalProperties: DataLogAdditionalProperties? {
        var props = DataLogAdditionalProperties()
        
        if let distance = totalDistance {
            let value = distance.doubleValue(for: .meter()).rounded(to: 4)
            props[.totalDistance] = "\(value)"
        }
        
        if let energyBurned = totalEnergyBurned {
            let value = energyBurned.doubleValue(for: .largeCalorie()).rounded(to: 4)
            props[.totalEnergyBurned] = "\(value)"
        }
        
        return props.isEmpty ? nil : props
    }
    
    private func makeEventLogs(parentId: String) -> [DataLog] {
        let events = workoutEvents ?? []
        guard !events.isEmpty else { return [] }
        
        return events.compactMap { event in
            DataLog(
                parentId: parentId,
                dataType: "exercise_event_" + event.description.camelToSnake,
                value: 1.0,
                source: sourceRevision.source.name,
                recordingMethod: recordingMethod,
                deviceType: sourceRevision.productType ?? "unknown",
                startDateTime: event.dateInterval.start,
                endDateTime: event.dateInterval.end,
                additionalProperties: nil
            )
        }
    }
    
    private func makeActivityLogs(parentId: String) -> [DataLog] {
        guard #available(iOS 16.0, *), !workoutActivities.isEmpty else { return [] }
        
        return workoutActivities.compactMap { activity in
            DataLog(
                parentId: parentId,
                dataType: "exercise_segment_" + activity.workoutConfiguration.activityType.name,
                value: 1.0,
                source: sourceRevision.source.name,
                recordingMethod: recordingMethod,
                deviceType: sourceRevision.productType ?? "unknown",
                startDateTime: activity.startDate,
                endDateTime: activity.endDate ?? activity.startDate + activity.duration,
                additionalProperties: nil
            )
        }
    }
}
