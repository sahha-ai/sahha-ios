protocol DeviceInfoSyncManagerProtocol: Sendable {
    func syncDeviceInfo() async
    func forceSyncDeviceInfo() async
}
