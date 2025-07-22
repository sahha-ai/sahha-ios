import HealthKit

extension HKSample {
    func toDataLog() -> [DataLog] {
        HKSampleToDataLogNormaliser.normalise(self)
    }
}
