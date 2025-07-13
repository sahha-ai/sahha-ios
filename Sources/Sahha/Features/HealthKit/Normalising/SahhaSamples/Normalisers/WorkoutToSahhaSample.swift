import HealthKit

enum WorkoutToSahhaSample {
    static let normalise: NormalisingEngine<HKSample, SahhaSample>.Normaliser = { sample in
        guard let sample = sample as? HKWorkout,
            let sensor = SahhaSensor.sensor(for: sample.sampleType),
            sensor == .exercise
        else { return [] }

        let duration = Calendar.current.dateComponents([.minute], from: sample.startDate, to: sample.endDate).minute ?? 0

        var stats: [SahhaStat] = []

        if #available(iOS 16.0, *), !sample.allStatistics.isEmpty {
            stats.append(
                contentsOf: sample.allStatistics.compactMap {
                    SahhaStat.create(from: $1)
                }
            )
        }

        return [
            SahhaSample(
                id: sample.uuid.uuidString,
                category: sensor.biomarkerCategory.rawValue,
                type: "exercise_\(sample.workoutActivityType.name)",
                value: Double(duration).rounded(toPlaces: 4),
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
