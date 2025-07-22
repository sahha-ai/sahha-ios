protocol DeviceIdStoring: Actor {
    func getDeviceId() async throws -> String
}
