protocol DeviceInfoCollector: Actor {
    func collect() async -> DeviceInformation
}
