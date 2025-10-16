protocol SensorStoreProtocol: Actor {
    func setSensors(_ sensors: Set<SahhaSensor>) throws
    func getSensors() throws -> Set<SahhaSensor>
    func hasSensor(_ sensor: SahhaSensor) -> Bool
}
