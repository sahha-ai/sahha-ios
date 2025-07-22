import HealthKit

enum HKWorkoutToSahhaSampleNormaliser {
    static func normalise(_ sample: HKSample) -> [SahhaSample] {
        guard let sample = sample as? HKWorkout,
            let sensor = HKWorkoutType.workoutType().sahhaSensor,
            sensor == .exercise
        else {
            return []
        }

        var stats: [SahhaStat] = []

        if #available(iOS 16.0, *), !sample.allStatistics.isEmpty {
            stats.append(
                contentsOf: sample.allStatistics.values.compactMap{ SahhaStat.fromHKStatistics($0) }
            )
        }

        let duration = Calendar.current.dateComponents([.minute], from: sample.startDate, to: sample.endDate).minute ?? 0
        let value = Double(duration).rounded(toPlaces: 4)

        return [
            SahhaSample(
                id: sample.uuid.uuidString,
                category: sensor.category.rawValue,
                type: "exercise_\(sample.workoutActivityType.name)",
                value: value,
                unit: sensor.unitString,
                startDateTime: sample.startDate,
                endDateTime: sample.endDate,
                recordingMethod: sample.recordingMethod.stringValue,
                source: sample.sourceId,
                stats: stats
            )
        ]
    }
}
