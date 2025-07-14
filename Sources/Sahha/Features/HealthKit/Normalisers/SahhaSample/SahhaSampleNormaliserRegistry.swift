import HealthKit

struct SahhaSampleNormaliserRegistry: NormaliserRegistry {
    static let normaliser = Normaliser<HKSample, SahhaSample>(
        key: \.sampleType.identifier,
        registry: [
            // Sleep
            HKCategoryTypeIdentifier.sleepAnalysis.rawValue: HKSleepAnalysisToSahhaSample.normalise,
            // Workout
            HKWorkoutTypeIdentifier: HKWorkoutToSahhaSample.normalise,
        ],
        fallback: FallbackSahhaSampleNormaliser.normalise
    )
}
