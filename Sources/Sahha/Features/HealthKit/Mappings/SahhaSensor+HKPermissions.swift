import HealthKit

extension SahhaSensor {
    var hkPermissions: Set<HKObjectType> {
        switch self {
        case .blood_pressure_diastolic, .blood_pressure_systolic:
            // Both diastolic and systolic permissions are required together for iOS 26+
            let diastolic = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)
            let systolic  = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)
            return Set([diastolic, systolic].compactMap { $0 })
        case .nutrition:
            return Set(SahhaSensor.allCases.filter { $0 != .nutrition && $0.dataLogType == .nutrition }.flatMap(\.hkPermissions))
        case .reproductive:
            return Set(SahhaSensor.allCases.filter { $0 != .reproductive && $0.dataLogType == .reproductive }.flatMap(\.hkPermissions))
        case .symptom:
            return Set(SahhaSensor.allCases.filter { $0 != .symptom && $0.dataLogType == .symptom }.flatMap(\.hkPermissions))
        default:
            if let primary = self.hkObjectType {
                return [primary]
            } else {
                return []
            }
        }
    }
}
