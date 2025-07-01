import HealthKit

protocol HKPermissionManagerProtocol: Sendable {
    func requestPermissions(for types: Set<HKObjectType>) async throws
    func getPermissionStatus(for types: Set<HKObjectType>) async throws -> HKAuthorizationRequestStatus
    func getPermissionStatus(for type: HKObjectType) -> HKAuthorizationStatus
}
