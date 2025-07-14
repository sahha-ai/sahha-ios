import HealthKit

enum HKWorkoutToSahhaSample {
    static let normalise: Normaliser<HKSample, SahhaSample>.NormaliserFn = { sample in
        guard
            let sample = sample as? HKWorkout,
            let metadata = SensorMapper.metadata(for: sample.sampleType),
            metadata.sensor == .exercise
        else {
            return []
        }
        
        let duration = Calendar.current.dateComponents([.minute], from: sample.startDate, to: sample.endDate).minute ?? 0

        var stats: [SahhaStat] = []

        if #available(iOS 16.0, *), !sample.allStatistics.isEmpty {
            stats.append(
                contentsOf: sample.allStatistics.compactMap {
                    SahhaStat.create(from: $1)
                }
            )
        }
        
        return [SahhaSample(
            id: sample.uuid.uuidString,
            category: metadata.biomarkerCategory.rawValue,
            type: "exercise_\(sample.workoutActivityType.name)",
            value: Double(duration).rounded(toPlaces: 4),
            unit: metadata.unitString,
            startDateTime: sample.startDate,
            endDateTime: sample.endDate,
            recordingMethod: sample.recordingMethod.stringValue,
            source: sample.sourceId,
            stats: stats
        )]
    }
}
