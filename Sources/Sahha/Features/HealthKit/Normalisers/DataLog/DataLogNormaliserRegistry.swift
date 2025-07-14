import HealthKit

struct DataLogNormaliserRegistry: NormaliserRegistry {
    static let normaliser = Normaliser<HKSample, DataLog>(
        key: \.sampleType.identifier,
        registry: [
            // Heart
            HKQuantityTypeIdentifier.heartRate.rawValue: HKHeartRateToDataLog.normalise,
            HKQuantityTypeIdentifier.restingHeartRate.rawValue: HKHeartRateToDataLog.normalise,
            HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue: HKHeartRateToDataLog.normalise,
            HKQuantityTypeIdentifier.walkingHeartRateAverage.rawValue: HKHeartRateToDataLog.normalise,
            // Blood
            HKQuantityTypeIdentifier.bloodGlucose.rawValue: HKBloodGlucoseToDataLog.normalise,
            // Sleep
            HKCategoryTypeIdentifier.sleepAnalysis.rawValue: HKSleepAnalysisToDataLog.normalise,
            // Oxygen
            HKQuantityTypeIdentifier.vo2Max.rawValue: HKVO2MaxToDataLog.normalise,
            // Exercise
            HKWorkoutTypeIdentifier: HKWorkoutToDataLog.normalise
        ],
        fallback: FallbackDataLogNormaliser.normalise
    )
}
