protocol DeviceInfoService: Sendable {
    func updateDeviceInfo(_ info: DeviceInformation) async throws
}
