import HealthKit

enum HKSampleToSahhaSampleRegistry {
    static let normaliser = NormalisingEngine<HKSample, SahhaSample>(
        key: \.sampleType.identifier,
        table: [
            // Sleep
            HKCategoryTypeIdentifier.sleepAnalysis.rawValue: SleepAnalysisToSahhaSample.normalise,
            // Workout
            HKWorkoutTypeIdentifier: WorkoutToSahhaSample.normalise,
        ],
        fallback: { sample in
            switch sample {
            case is HKQuantitySample: return QuantityToSahhaSample.normalise(sample)
            default: return []
            }
        }
    )
}
