protocol SensorStoreProtocol: Actor {
    func setSensors(_ sensors: Set<SahhaSensor>) throws
    func getSensors() throws -> Set<SahhaSensor>
    func hasSensor(_ sensor: SahhaSensor) -> Bool
    func setSensorStatuses(_ statuses: [SahhaSensor: SahhaSensorStatus])
    func getSensorStatuses() -> [SahhaSensor: SahhaSensorStatus]
}
