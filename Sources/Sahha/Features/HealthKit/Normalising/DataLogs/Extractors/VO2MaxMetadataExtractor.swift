import HealthKit

struct VO2MaxMetadataExtractor: PropertyExtractor {
    func extract(from sample: HKSample) -> [String: String]? {
        guard let sample = sample as? HKQuantitySample,
              let metadata = sample.metadata else {
            return nil
        }
        
        var properties: [String: String] = [:]
        
        if let rawValue = metadata[HKMetadataKeyHeartRateSensorLocation] as? NSNumber,
           let value = HKVO2MaxTestType(rawValue: rawValue.intValue) {
            properties["measurement_method"] = value.stringValue
        }
        
        return properties.isEmpty ? nil : properties
    }
}
