import HealthKit

protocol HKPermissionHandler: Sendable {
    func requestReadPermissions(for types: Set<HKObjectType>) async throws
    func checkReadPermissions(for types: Set<HKObjectType>) async throws -> HKAuthorizationRequestStatus
    func hasReadPermission(for type: HKObjectType) async -> Bool
}

final class HKPermissionHandlerImpl: HKPermissionHandler {
    private let healthStore: HKHealthStore
    
    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }
    
    func requestReadPermissions(for types: Set<HKObjectType>) async throws {
        try await healthStore.requestAuthorization(toShare: [], read: types)
    }
    
    func checkReadPermissions(for types: Set<HKObjectType>) async throws -> HKAuthorizationRequestStatus {
        try await self.healthStore.statusForAuthorizationRequest(toShare: [], read: types)
    }
    
    func hasReadPermission(for type: HKObjectType) async -> Bool {
        do {
            let status = try await self.checkReadPermissions(for: [type])
            return status == .unnecessary
        } catch {
            return false
        }
    }
}
