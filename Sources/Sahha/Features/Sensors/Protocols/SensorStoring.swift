protocol SensorStoring: Actor, Disposable {
    func saveSensors(_ sensors: Set<SahhaSensor>) async
    func loadSensors() async -> Set<SahhaSensor>
    func clearSensors() async
}
