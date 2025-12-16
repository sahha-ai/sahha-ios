import Foundation

final class DeviceInfoSyncLifecycleListener: LifecycleListener {
    private let deviceInfoSyncManager: DeviceInfoSyncManagerProtocol
    private let throttleInterval: TimeInterval
    private let syncActor = SyncThrottleActor()

    init(
        deviceInfoSyncManager: DeviceInfoSyncManagerProtocol,
        throttleInterval: TimeInterval = 6 * 60 * 60  // 6 hours default
    ) {
        self.deviceInfoSyncManager = deviceInfoSyncManager
        self.throttleInterval = throttleInterval
    }

    func handleLifecycleEvent(_ event: LifecycleEvent) async {
        // Only sync on foreground events to reduce redundancy
        guard event == .app_resume else { return }
        
        await syncActor.performThrottled(interval: throttleInterval) { [weak self] in
            guard let self else { return }
            await self.deviceInfoSyncManager.syncDeviceInfo()
        }
    }
}

/// Actor to ensure thread-safe throttling
private actor SyncThrottleActor {
    private var lastAttempt: Date?
    
    func performThrottled(interval: TimeInterval, action: @escaping () async -> Void) async {
        let now = Date()
        
        if let last = lastAttempt, now.timeIntervalSince(last) < interval {
            // Too soon - skip
            return
        }
        
        lastAttempt = now
        await action()
    }
}
