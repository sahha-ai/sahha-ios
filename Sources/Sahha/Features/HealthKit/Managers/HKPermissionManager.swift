import HealthKit

final class HKPermissionManager: HKPermissionManagerProtocol {
    private let healthStore: HKHealthStore
    
    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }
    
    func requestPermissions(for types: Set<HKObjectType>) async throws {
        guard !types.isEmpty else {
            throw HealthKitError.emptyRequest
        }
        
        try await healthStore.requestAuthorization(toShare: [], read: types)
    }
    
    func getPermissionStatus(for types: Set<HKObjectType>) async throws -> HKAuthorizationRequestStatus {
        guard !types.isEmpty else {
            throw HealthKitError.emptyRequest
        }
        
        return try await healthStore.statusForAuthorizationRequest(toShare: [], read: types)
    }
    
    func getPermissionStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        healthStore.authorizationStatus(for: type)
    }
}
