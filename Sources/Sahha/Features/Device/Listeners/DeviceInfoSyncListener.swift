import Foundation

final class DeviceInfoSyncListener: LifecycleListener {
    private let manager: DeviceInfoManager

    init(manager: DeviceInfoManager) {
        self.manager = manager
    }

    func handleLifecycleEvent(_ event: LifecycleEvent) async {
        guard event == .app_resume else { return }
    
        do {
            try await manager.sync()
        } catch {
            print("DeviceInfo sync failed on resume:", error)
        }
    }
}
