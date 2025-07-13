import HealthKit

struct BloodGlucoseMetadataExtractor: PropertyExtractor {
    func extract(from sample: HKSample) -> [String: String]? {
        guard let sample = sample as? HKQuantitySample,
              let metadata = sample.metadata else {
            return nil
        }
        
        var properties: [String: String] = [:]
        
        if let rawValue = metadata[HKMetadataKeyBloodGlucoseMealTime] as? NSNumber,
           let mealTime = HKBloodGlucoseMealTime(rawValue: rawValue.intValue) {
            properties["relation_to_meal"] = mealTime.stringValue
        }
        
        return properties.isEmpty ? nil : properties
    }
}
