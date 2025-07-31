import HealthKit

final class HKSampleToSahhaSampleNormaliserRegistry: HKSampleToSahhaSampleNormaliserProtocol {
    private static let normalisers: [String: HKSampleToSahhaSampleNormaliserProtocol] = [
        // Sleep
        HKCategoryTypeIdentifier.sleepAnalysis.rawValue: HKSleepAnalysisToSahhaSampleNormaliser(),
        // Exercise
        HKWorkoutTypeIdentifier: HKWorkoutToSahhaSampleNormaliser(),
    ]

    private static let fallback = FallbackHKSampleToSahhaSampleNormaliser()

    func normalise(_ sample: HKSample) -> [SahhaSample] {
        let key = sample.sampleType.identifier
        let normaliser = Self.normalisers[key] ?? Self.fallback
        return normaliser.normalise(sample)
    }
}
