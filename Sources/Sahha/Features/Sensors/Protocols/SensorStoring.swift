protocol SensorStoring: Actor {
    func saveSensors(_ sensors: Set<SahhaSensor>) async
    func loadSensors() async -> Set<SahhaSensor>
    func clearSensors() async
}
