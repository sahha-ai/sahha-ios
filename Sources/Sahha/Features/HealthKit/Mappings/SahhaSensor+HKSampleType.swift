import HealthKit

extension SahhaSensor {
    var hkSampleType: HKSampleType? {
        return self.hkObjectType as? HKSampleType
    }
}
