import HealthKit

final class HealthKitPermissionsService: HealthKitPermissionsServiceProtocol {
    private let healthStore: HKHealthStore
    
    init(healthStore: HKHealthStore = .init()) {
        self.healthStore = healthStore
    }
    
    func requestPermissions(for sensors: Set<SahhaSensor>) async throws {
        guard !sensors.isEmpty else {
            throw SahhaError(message: "Sensor set cannot be empty.")
        }
        
        let permissions = Set(sensors.flatMap(\.hkPermissions))
        
        guard !permissions.isEmpty else {
            throw SahhaError(message: "Health data types not specified.")
        }
        
        try await healthStore.requestAuthorization(toShare: [], read: permissions)
    }
    
    func getPermissionsStatus(for sensors: Set<SahhaSensor>) async throws -> HKAuthorizationRequestStatus {
        guard !sensors.isEmpty else {
            throw SahhaError(message: "Sensor set cannot be empty.")
        }
        
        let permissions = Set(sensors.flatMap(\.hkPermissions))
        
        guard !permissions.isEmpty else {
            throw SahhaError(message: "Health data types not specified.")
        }
        
        return try await healthStore.statusForAuthorizationRequest(toShare: [], read: permissions)
    }
    
    func hasPermissions(for sensor: SahhaSensor) async throws -> Bool {
        let permissions = sensor.hkPermissions
        
        if permissions.isEmpty { return false }
        
        let status = try await healthStore.statusForAuthorizationRequest(toShare: [], read: permissions)
        
        return status == .unnecessary
    }
}
