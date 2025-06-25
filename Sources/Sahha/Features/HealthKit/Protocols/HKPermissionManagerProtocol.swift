import HealthKit

protocol HKPermissionManagerProtocol: Sendable {
    func requestPermissions(for types: Set<HKObjectType>) async throws
}
