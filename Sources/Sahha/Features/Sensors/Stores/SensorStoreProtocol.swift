protocol SensorStoreProtocol: Actor {
    func setSensors(_ sensors: Set<SahhaSensor>) throws
    func getSensors() throws -> Set<SahhaSensor>
    /// Atomically captures the current set, writes the new one, and returns the
    /// captured set. Implementations must do all of it in a single actor turn:
    /// concurrent replaces then serialize whole, so the returned previous-sets
    /// chain across calls without loss or duplication.
    ///
    /// Write-always contract: a failing read must not block the write — the new
    /// set is persisted first and the read failure rethrown after.
    func replaceSensors(_ sensors: Set<SahhaSensor>) throws -> Set<SahhaSensor>
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

    /// Default composed from the read/write primitives. Actor-isolated with no
    /// suspension points, so it is one actor turn even for conformers that rely
    /// on it. A read failure surfaces only after the write has been attempted.
    func replaceSensors(_ sensors: Set<SahhaSensor>) throws -> Set<SahhaSensor> {
        let previous: Set<SahhaSensor>
        do {
            previous = try getSensors()
        } catch {
            try setSensors(sensors)
            throw error
        }
        try setSensors(sensors)
        return previous
    }
}
