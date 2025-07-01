protocol HKManagerProtocol: Sendable, DisposableAsync {
    func enableSensors(_ sensors: Set<SahhaSensor>) async throws
    func getSensorStatus(_ sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus
    func disableSensors(_ sensors: Set<SahhaSensor>) async throws
}
