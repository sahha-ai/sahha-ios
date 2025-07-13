import HealthKit

struct HeartRateMetadataExtractor: PropertyExtractor {
    func extract(from sample: HKSample) -> [String: String]? {
        guard let sample = sample as? HKQuantitySample,
              let metadata = sample.metadata else {
            return nil
        }
        
        var properties: [String: String] = [:]
        
        if let rawValue = metadata[HKMetadataKeyHeartRateSensorLocation] as? NSNumber,
           let sensorLocation = HKHeartRateSensorLocation(rawValue: rawValue.intValue) {
            properties["sensor_location"] = sensorLocation.stringValue
        }
        
        if let rawValue = metadata[HKMetadataKeyHeartRateMotionContext] as? NSNumber,
           let motionContext = HKHeartRateMotionContext(rawValue: rawValue.intValue) {
            properties["motion_context"] = motionContext.stringValue
        }
        
        return properties.isEmpty ? nil : properties
    }
}
