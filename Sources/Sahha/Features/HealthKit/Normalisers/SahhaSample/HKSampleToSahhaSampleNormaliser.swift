import HealthKit

enum HKSampleToSahhaSampleNormaliser {
    private typealias Normaliser = @Sendable (HKSample) -> [SahhaSample]

    private static let registry: [String: Normaliser] = [
        // Sleep
        HKCategoryTypeIdentifier.sleepAnalysis.rawValue: HKSleepAnalysisToSahhaSampleNormaliser.normalise,
        // Exercise
        HKWorkoutTypeIdentifier: HKWorkoutToSahhaSampleNormaliser.normalise,
    ]

    static func normalise(_ sample: HKSample) -> [SahhaSample] {
        let id = sample.sampleType.identifier
        return registry[id]?(sample) ?? defaultNormaliser(sample)
    }

    private static func defaultNormaliser(_ sample: HKSample) -> [SahhaSample] {
        guard
            let sample = sample as? HKQuantitySample,
                let sensor = sample.quantityType.sahhaSensor,
                let unit = sensor.hkUnit else {
            return []
        }

        return [
            SahhaSample(
                id: sample.uuid.uuidString,
                category: sensor.category.rawValue,
                type: sensor.rawValue,
                value: sample.quantity.doubleValue(for: unit).rounded(toPlaces: 4),
                unit: sensor.unitString,
                startDateTime: sample.startDate,
                endDateTime: sample.endDate,
                recordingMethod: sample.recordingMethod.stringValue,
                source: sample.sourceId
            )
        ]
    }
}
