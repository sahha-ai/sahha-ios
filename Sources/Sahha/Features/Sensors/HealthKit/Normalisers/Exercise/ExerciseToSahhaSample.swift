import HealthKit

enum ExerciseToSahhaSample {
    static func normalise(_ samples: [HKSample], sensor: SahhaSensor) -> [SahhaSample] {
        guard sensor == .exercise else {
            return []
        }

        return samples.compactMap { sample in
            guard let workout = sample as? HKWorkout else {
                return nil
            }

            let duration = Calendar.current.dateComponents([.minute], from: workout.startDate, to: workout.endDate).minute ?? 0

            var stats: [SahhaStat] = []
            
            if #available(iOS 16.0, *), !workout.allStatistics.isEmpty {
                stats.append(
                    contentsOf: workout.allStatistics.compactMap { $1.toSahhaStat() }
                )
            }
            
            return SahhaSample(
                id: workout.uuid.uuidString,
                category: sensor.category.rawValue,
                type: "exercise_\(workout.workoutActivityType.name)",
                value: Double(duration).rounded(toPlaces: 4),
                unit: sensor.unitString,
                startDateTime: workout.startDate,
                endDateTime: workout.endDate,
                recordingMethod: workout.recordingMethod.stringValue,
                source: workout.sourceId,
                stats: stats
            )
        }
    }
}
