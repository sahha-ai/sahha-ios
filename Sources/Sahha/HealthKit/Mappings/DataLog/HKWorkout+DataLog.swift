import HealthKit

// TODO: Finish full implementation

extension HKWorkout {
    func toDataLog_internal() async -> DataLog? {
        let sensor: SahhaSensor = .exercise
        let dataType = "exercise_session_" + workoutActivityType.name

        return DataLog(
            dataType: dataType,
            value: 1.0,
            source: sourceRevision.source.name,
            recordingMethod: recordingMethod,
            deviceType: sourceRevision.productType ?? "unknown",
            startDateTime: startDate,
            endDateTime: endDate,
            additionalProperties: [:] // TODO: Populate if needed later
        )
    }
}
