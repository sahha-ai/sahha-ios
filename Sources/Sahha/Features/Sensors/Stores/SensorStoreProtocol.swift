protocol SensorStoreProtocol: Actor {
    func setSensors(_ sensors: Set<SahhaSensor>) throws
    func getSensors() throws -> Set<SahhaSensor>
    func hasSensor(_ sensor: SahhaSensor) -> Bool
    func setSensorStatuses(_ statuses: [SahhaSensor: SahhaSensorStatus])
    func getSensorStatuses() -> [SahhaSensor: SahhaSensorStatus]
    /// Returns the anomaly latched by the most recent lenient read, exactly
    /// once; nil thereafter. Reads themselves never consume it — the
    /// authenticated bring-up drains and posts it.
    func drainPendingAnomaly() -> SensorStoreAnomaly?
}

extension SensorStoreProtocol {
    /// Default so lightweight test doubles need not track anomalies.
    func drainPendingAnomaly() -> SensorStoreAnomaly? { nil }
}
