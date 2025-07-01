protocol SensorsManagerProtocol: Actor, DisposableAsync {
    func resumeSensors() async throws
    func enableSensors(_ sensors: Set<SahhaSensor>) async throws
    func getSensorStatus(_ sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus
    func getEnabledSensors() async -> Set<SahhaSensor>
}
