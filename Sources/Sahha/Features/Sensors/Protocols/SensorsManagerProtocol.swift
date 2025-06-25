protocol SensorsManagerProtocol: Actor, DisposableAsync {
    func enableSensors(_ sensors: Set<SahhaSensor>) async
    func getSensorStatus(_ sensor: Set<SahhaSensor>) async -> SahhaSensorStatus
}
