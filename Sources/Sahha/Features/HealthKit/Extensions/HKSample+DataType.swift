import HealthKit

extension HKSample {
    var dataType: String {
        guard let sensor = SensorMapper.sensor(for: self.sampleType) else { return "Unknown" }
        return sensor.rawValue
    }
}
