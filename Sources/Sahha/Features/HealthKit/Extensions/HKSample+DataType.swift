import HealthKit

extension HKSample {
    var dataType: String {
        guard let sensor = HKSensorMapper.sahhaSensor(for: self.sampleType) else { return "unknown" }
        return sensor.rawValue
    }
}
