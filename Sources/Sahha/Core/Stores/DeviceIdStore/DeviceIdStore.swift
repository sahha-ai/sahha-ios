protocol DeviceIdStore: Actor {
    func getId() async -> String
}
