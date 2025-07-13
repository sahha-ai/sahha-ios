import HealthKit

struct WorkoutPropertiesExtractor: PropertyExtractor {
    func extract(from sample: HKSample) -> [String: String]? {
        guard let sample = sample as? HKWorkout else {
            return nil
        }
        
        var properties: [String: String] = [:]
        
        if let distance = sample.totalDistance {
            let value = distance.doubleValue(for: .meter()).rounded(toPlaces: 4)
            properties["total_distance"] = "\(value)"
        }
        
        if let energy = sample.totalEnergyBurned {
            let value = energy.doubleValue(for: .largeCalorie()).rounded(toPlaces: 4)
            properties["total_energy_burned"] = "\(value)"
        }
        
        return properties.isEmpty ? nil : properties
    }
}
