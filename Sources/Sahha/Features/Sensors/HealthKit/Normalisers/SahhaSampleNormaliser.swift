import HealthKit

struct SahhaSampleNormaliser {
    private static let registry: [SahhaSensor: @Sendable ([HKSample], SahhaSensor) -> [SahhaSample]] = [
        .sleep: SleepToSahhaSample.normalise,
        .exercise: ExerciseToSahhaSample.normalise
    ]

    private static let fallback: @Sendable ([HKSample], SahhaSensor) -> [SahhaSample] = { samples, sensor in
        return samples.compactMap { sample in
            guard let qtySample = sample as? HKQuantitySample, let unit = sensor.hkUnit else {
                return nil
            }
            
            return SahhaSample(
                id: qtySample.uuid.uuidString,
                category: sensor.category.rawValue,
                type: sensor.rawValue,
                value: qtySample.quantity.doubleValue(for: unit).rounded(toPlaces: 4),
                unit: sensor.unitString,
                startDateTime: qtySample.startDate,
                endDateTime: qtySample.endDate,
                recordingMethod: qtySample.recordingMethod.stringValue,
                source: qtySample.sourceId
            )
        }
    }

    static func normalise(_ samples: [HKSample], sensor: SahhaSensor) -> [SahhaSample] {
        let normaliser = registry[sensor] ?? fallback
        return normaliser(samples, sensor)
    }
}
