import HealthKit

extension SahhaSensor {
    /// All HealthKit object types required for this sensor's permission.
    var hkPermissions: Set<HKObjectType> {
        // Compose your extra permissions here
        switch self {
        case .blood_pressure_diastolic, .blood_pressure_systolic:
            // Both diastolic and systolic are required together
            let diastolic = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)
            let systolic  = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)
            return Set([diastolic, systolic].compactMap { $0 })
        // Add other edge cases here if needed
        default:
            if let primary = self.hkObjectType {
                return [primary]
            } else {
                return []
            }
        }
    }
}
