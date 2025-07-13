import HealthKit

enum HKSampleToDataLogRegistry {
    static let normaliser = NormalisingEngine<HKSample, DataLog>(
        key: \.sampleType.identifier,
        table: [
            // Heart rate
            HKQuantityTypeIdentifier.heartRate.rawValue: HeartRateToDataLog.normalise,
            HKQuantityTypeIdentifier.restingHeartRate.rawValue: HeartRateToDataLog.normalise,
            HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue: HeartRateToDataLog.normalise,
            HKQuantityTypeIdentifier.walkingHeartRateAverage.rawValue: HeartRateToDataLog.normalise,
            // Blood
            HKQuantityTypeIdentifier.bloodGlucose.rawValue: BloodGlucoseToDataLog.normalise,
            // Oxygen
            HKQuantityTypeIdentifier.vo2Max.rawValue: VO2MaxToDataLog.normalise,
            // Sleep
            HKCategoryTypeIdentifier.sleepAnalysis.rawValue: SleepAnalysisToDataLog.normalise,
            // Workout
            HKWorkoutTypeIdentifier: WorkoutToDataLog.normalise,
        ],
        fallback: { sample in
            switch sample {
            case is HKQuantitySample: return QuantityToDataLog.normalise(sample)
            default: return []
            }
        }
    )
}
