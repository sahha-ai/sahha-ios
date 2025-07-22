protocol HKPermissionManager: Sendable {
    func requestPermissions(for sensors: Set<SahhaSensor>) async throws
    func permissionStatus(for sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus
    func hasPermissions(for sensor: SahhaSensor) async throws -> Bool
}
