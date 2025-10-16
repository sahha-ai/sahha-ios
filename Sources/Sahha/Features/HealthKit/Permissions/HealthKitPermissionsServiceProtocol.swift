import HealthKit

protocol HealthKitPermissionsServiceProtocol: Sendable {
    func requestPermissions(for sensors: Set<SahhaSensor>) async throws
    func getPermissionsStatus(for sensors: Set<SahhaSensor>) async throws -> HKAuthorizationRequestStatus
    func hasPermissions(for sensor: SahhaSensor) async throws -> Bool
}
