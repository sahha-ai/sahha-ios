protocol DeviceInfoCollecting: Sendable {
    func collect() async throws -> DeviceInformation
}
