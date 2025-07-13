final class DeviceInformationSyncHandler: LifecycleHandler {
    private let store: DeviceInformationStore
    private let tokenManager: TokenManager

    init(store: DeviceInformationStore, tokenManager: TokenManager) {
        self.store = store
        self.tokenManager = tokenManager
    }

    func handleLifecycleEvent(event: LifecycleEvent) async {
        guard await tokenManager.getProfileToken() != nil else { return }
        await store.syncIfNeeded()
    }
}
