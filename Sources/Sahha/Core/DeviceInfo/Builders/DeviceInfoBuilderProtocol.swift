protocol DeviceInfoBuilderProtocol: Sendable {
    func build() async -> DeviceInfo
}
