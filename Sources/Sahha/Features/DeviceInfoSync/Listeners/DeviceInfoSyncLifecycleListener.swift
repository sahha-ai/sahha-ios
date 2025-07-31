final class DeviceInfoSyncLifecycleListener: LifecycleListener {
    private let deviceInfoSyncManager: DeviceInfoSyncManagerProtocol

    init(deviceInfoSyncManager: DeviceInfoSyncManagerProtocol) {
        self.deviceInfoSyncManager = deviceInfoSyncManager
    }

    func handleLifecycleEvent(_ event: LifecycleEvent) async {
        await deviceInfoSyncManager.syncDeviceInfo()
    }
}
