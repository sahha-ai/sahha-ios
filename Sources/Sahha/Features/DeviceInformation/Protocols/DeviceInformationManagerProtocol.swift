protocol DeviceInformationManagerProtocol: Actor {
    func getDeviceInformation() async -> DeviceInformation
    func requiresSync() async -> Bool
}
