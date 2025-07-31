protocol HealthKitDataLogCoordinatorProtocol: Sendable {
    func startDataLogCollection(for sensors: Set<SahhaSensor>) async throws
    func stopDataLogCollection(for sensors: Set<SahhaSensor>) async throws
    func querySensors(_ sensors: Set<SahhaSensor>) async
}
