import HealthKit

final class HKWorkoutToSahhaSampleNormaliser: HKSampleToSahhaSampleNormaliserProtocol {
    func normalise(_ sample: HKSample) -> [SahhaSample] {
        guard let sample = sample as? HKWorkout,
            let sensor = HKWorkoutType.workoutType().sahhaSensor,
            sensor == .exercise
        else {
            return []
        }

        var stats: [SahhaStat] = []

        if #available(iOS 16.0, *), !sample.allStatistics.isEmpty {
            let statistics = sample.allStatistics.values
            
            stats = statistics.compactMap { stat in
                guard let unit = sensor.hkUnit else { return nil }
                return SahhaStat(
                    category: sensor.dataLogType.stringValue,
                    type: sensor.rawValue,
                    aggregation: stat.aggregationType.rawValue,
                    periodicity: Periodicity.daily.rawValue,
                    value: stat.aggregationValue(for: unit).rounded(toPlaces: 4),
                    unit: sensor.unitString,
                    startDateTime: stat.startDate,
                    endDateTime: stat.endDate,
                    sources: stat.sources?.map(\.bundleIdentifier) ?? []
                )
            }
        }

        let duration = Calendar.current.dateComponents([.minute], from: sample.startDate, to: sample.endDate).minute ?? 0
        let value = Double(duration).rounded(toPlaces: 4)

        return [
            SahhaSample(
                id: sample.uuid.uuidString,
                category: sensor.dataLogType.stringValue,
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
