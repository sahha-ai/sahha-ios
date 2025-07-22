protocol DeviceInfoSyncing: Actor, Disposable {
    func sync() async throws
    func forceSync() async throws
}
