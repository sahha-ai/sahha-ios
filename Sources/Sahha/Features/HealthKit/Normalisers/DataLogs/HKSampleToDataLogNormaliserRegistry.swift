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

    private static let fallback = FallbackHKSampleToDataLogNormaliser()

    func normalise(_ sample: HKSample) -> [DataLog] {
        let key = sample.sampleType.identifier
        let normaliser = Self.normalisers[key] ?? Self.fallback
        return normaliser.normalise(sample)
    }
}
