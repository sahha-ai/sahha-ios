protocol DeviceIdProviderProtocol: Sendable {
    func deviceId() async -> String
}
