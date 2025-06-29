protocol DeviceInformationManagerProtocol: Actor, DisposableAsync {
    func getDeviceInformation() async -> DeviceInformation
    func requiresSync() async -> Bool
    func start() async
}
