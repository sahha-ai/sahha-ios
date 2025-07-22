protocol SensorManaging: Sendable {
    func enableSensors(_ sensors: Set<SahhaSensor>) async throws
    func resumeSensors() async throws
    func getSensorStatus(_ sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus
}
