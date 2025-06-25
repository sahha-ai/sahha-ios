protocol DeviceInformationServiceProtocol: Sendable {
    func updateDeviceInformation(_ deviceInformation: DeviceInformation) async throws
}
