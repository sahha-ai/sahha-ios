import HealthKit

extension HKSample {
    var logType: LogType {
        guard let sensor = SensorMapper.sensor(for: self.sampleType) else { return .unknown }
        return sensor.logType
    }
}
