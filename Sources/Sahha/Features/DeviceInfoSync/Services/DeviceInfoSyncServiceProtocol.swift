protocol DeviceInfoSyncServiceProtocol: Sendable {
    func syncDeviceInfo(_ deviceInfo: DeviceInfoRequest) async throws
}
