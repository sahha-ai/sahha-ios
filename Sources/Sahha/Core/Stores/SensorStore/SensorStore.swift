protocol SensorStore: Actor, Disposable {
    func setEnabledSensors(_ sensors: Set<SahhaSensor>)
    func getEnabledSensors() -> Set<SahhaSensor>
}
