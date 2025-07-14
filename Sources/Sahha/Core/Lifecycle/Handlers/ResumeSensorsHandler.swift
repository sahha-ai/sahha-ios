final class ResumeSensorsHandler: LifecycleHandler {
    private let hkManager: HKManager
    private let tokenManager: TokenManager

    init(hkManager: HKManager,tokenManager: TokenManager) {
        self.hkManager = hkManager
        self.tokenManager = tokenManager
    }

    func handleLifecycleEvent(event: LifecycleEvent) async {
        guard await tokenManager.getProfileToken() != nil else { return }
        await hkManager.resumeSensors()
    }
}
