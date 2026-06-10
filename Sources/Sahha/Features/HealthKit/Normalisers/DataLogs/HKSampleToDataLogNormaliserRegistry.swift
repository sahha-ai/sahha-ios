import HealthKit

final class HKSampleToDataLogNormaliserRegistry: HKSampleToDataLogNormaliserProtocol {
    private static let normalisers: [String: HKSampleToDataLogNormaliserProtocol] = [
        // Heart rate
        HKQuantityTypeIdentifier.heartRate.rawValue: HKHeartRateToDataLogNormaliser(),
        HKQuantityTypeIdentifier.restingHeartRate.rawValue: HKHeartRateToDataLogNormaliser(),
        HKQuantityTypeIdentifier.walkingHeartRateAverage.rawValue: HKHeartRateToDataLogNormaliser(),
        HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue: HKHeartRateToDataLogNormaliser(),
        // VO2 max
        HKQuantityTypeIdentifier.vo2Max.rawValue: HKVO2MaxToDataLogNormaliser(),
        // Blood glucose
        HKQuantityTypeIdentifier.bloodGlucose.rawValue: HKBloodGlucoseToDataLogNormaliser(),
        // Sleep
        HKCategoryTypeIdentifier.sleepAnalysis.rawValue: HKSleepAnalysisToDataLogNormaliser(),
        // Exercise
        HKWorkoutTypeIdentifier: HKWorkoutToDataLogNormaliser()
    ]

    private static let quantityFallback = FallbackHKSampleToDataLogNormaliser()
    private static let categoryFallback = HKCategoryToDataLogNormaliser()

    func normalise(_ sample: HKSample, profileId: String?) -> [DataLog] {
        let key = sample.sampleType.identifier

        // Check registered normalisers first
        if let normaliser = Self.normalisers[key] {
            return normaliser.normalise(sample, profileId: profileId)
        }

        // Use appropriate fallback based on sample type
        if sample is HKCategorySample {
            return Self.categoryFallback.normalise(sample, profileId: profileId)
        } else {
            return Self.quantityFallback.normalise(sample, profileId: profileId)
        }
    }

    func normalise(_ samples: [HKSample], profileId: String?) -> [DataLog] {
        // Sleep sessions are derived by clustering the batch, so sleep samples
        // must reach their normaliser together rather than one at a time.
        let sleepKey = HKCategoryTypeIdentifier.sleepAnalysis.rawValue
        var sleepSamples: [HKSample] = []
        var logs: [DataLog] = []

        for sample in samples {
            if sample.sampleType.identifier == sleepKey {
                sleepSamples.append(sample)
            } else {
                logs.append(contentsOf: normalise(sample, profileId: profileId))
            }
        }

        if !sleepSamples.isEmpty, let sleepNormaliser = Self.normalisers[sleepKey] {
            logs.append(contentsOf: sleepNormaliser.normalise(sleepSamples, profileId: profileId))
        }

        return logs
    }
}
