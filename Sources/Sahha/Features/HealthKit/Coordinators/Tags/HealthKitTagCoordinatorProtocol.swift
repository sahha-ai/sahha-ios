protocol HealthKitTagCoordinatorProtocol: Sendable {
    func startTagCollection(for sensors: Set<SahhaSensor>) async throws
    func stopTagCollection(for sensors: Set<SahhaSensor>) async throws
    func querySensors(_ sensors: Set<SahhaSensor>) async -> [SensorQueryResult]
}
