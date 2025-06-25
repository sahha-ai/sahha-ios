protocol HKManagerProtocol: Sendable {
    func enableSensors(_ sensors: Set<SahhaSensor>) async throws
}
