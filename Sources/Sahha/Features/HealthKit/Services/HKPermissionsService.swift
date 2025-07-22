import HealthKit

final class HKPermissionsService: HKPermissionsProviding {
    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore = .init()) {
        self.healthStore = healthStore
    }
    
    func requestPermissions(for sensors: Set<SahhaSensor>) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthKitUnavailable
        }
        
        let types = Set(sensors.flatMap { $0.hkPermissions })
        try await healthStore.requestAuthorization(toShare: [], read: types)
    }

    func checkPermissions(for sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthKitUnavailable
        }
        
        let types = Set(sensors.flatMap { $0.hkPermissions })
        
        let status = try await healthStore.statusForAuthorizationRequest(toShare: [], read: types)
        
        if case .unnecessary = status {
            return .enabled
        }
        
        return .pending
    }
    
    func hasPermission(for sensor: SahhaSensor) async throws -> Bool {
        try await checkPermissions(for: [sensor]) == .enabled
    }
}
