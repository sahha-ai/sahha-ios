import HealthKit

extension SahhaSensor {
    var hkPermissions: Set<HKObjectType> {
        switch self {
        case .blood_pressure_diastolic, .blood_pressure_systolic:
            // Both diastolic and systolic permissions are required together for iOS 26+
            let diastolic = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)
            let systolic  = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)
            return Set([diastolic, systolic].compactMap { $0 })
        default:
            if let primary = self.hkObjectType {
                return [primary]
            } else {
                return []
            }
        }
    }
}
