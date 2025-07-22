import HealthKit

extension HKObjectType {
    var sahhaSensor: SahhaSensor? {
        HKSensorMapping.reverse[self]
    }
}
