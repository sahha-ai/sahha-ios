protocol HKManagerProtocol: Sendable, DisposableAsync {
    func enableSensors(_ sensors: Set<SahhaSensor>) async throws
    func disableSensors(_ sensors: Set<SahhaSensor>) async throws
}
