import HealthKit

extension HKSample {
    func toSahhaSample() -> [SahhaSample] {
        HKSampleToSahhaSampleNormaliser.normalise(self)
    }
}
