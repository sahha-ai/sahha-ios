import HealthKit

enum HKSampleToDataLogNormaliser {
    private typealias Normaliser = @Sendable (HKSample) -> [DataLog]

    private static let registry: [String: Normaliser] = [
        // Heart rate
        HKQuantityTypeIdentifier.heartRate.rawValue: HKHeartRateToDataLogNormaliser.normalise,
        HKQuantityTypeIdentifier.restingHeartRate.rawValue: HKHeartRateToDataLogNormaliser.normalise,
        HKQuantityTypeIdentifier.walkingHeartRateAverage.rawValue: HKHeartRateToDataLogNormaliser.normalise,
        HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue: HKHeartRateToDataLogNormaliser.normalise,
        // VO2 max
        HKQuantityTypeIdentifier.vo2Max.rawValue: HKVO2MaxToDataLogNormaliser.normalise,
        // Blood glucose
        HKQuantityTypeIdentifier.bloodGlucose.rawValue: HKBloodGlucoseToDataLogNormaliser.normalise,
        // Sleep
        HKCategoryTypeIdentifier.sleepAnalysis.rawValue: HKSleepAnalysisToDataLogNormaliser.normalise,
        // Exercise
        HKWorkoutTypeIdentifier: HKWorkoutToDataLogNormaliser.normalise,
    ]

    static func normalise(_ sample: HKSample) -> [DataLog] {
        let id = sample.sampleType.identifier
        return registry[id]?(sample) ?? defaultNormaliser(sample)
    }

    private static func defaultNormaliser(_ sample: HKSample) -> [DataLog] {
        guard let sample = sample as? HKQuantitySample,
              let sensor = sample.quantityType.sahhaSensor,
            let unit = sensor.hkUnit
        else { return [] }

        let value = sample.quantity.doubleValue(for: unit).rounded(toPlaces: 4)

        return [
            DataLog(
                logType: sensor.logType,
                dataType: sensor.rawValue,
                value: value,
                unit: sensor.unitString,
                source: sample.sourceId,
                recordingMethod: sample.recordingMethod,
                deviceType: sample.deviceType,
                startDate: sample.startDate,
                endDate: sample.endDate
            )
        ]
    }
}
