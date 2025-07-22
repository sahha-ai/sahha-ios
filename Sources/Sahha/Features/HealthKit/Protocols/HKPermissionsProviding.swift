protocol HKPermissionsProviding: Sendable {
    func requestPermissions(for sensors: Set<SahhaSensor>) async throws
    func checkPermissions(for sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus
    func hasPermission(for sensor: SahhaSensor) async throws -> Bool
}
