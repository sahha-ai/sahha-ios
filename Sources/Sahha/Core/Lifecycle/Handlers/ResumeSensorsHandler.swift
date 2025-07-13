final class ResumeSensorsHandler: LifecycleHandler {
    private let sensorManager: SensorManager
    private let tokenManager: TokenManager

    init(sensorManager: SensorManager,tokenManager: TokenManager) {
        self.sensorManager = sensorManager
        self.tokenManager = tokenManager
    }

    func handleLifecycleEvent(event: LifecycleEvent) async {
        guard await tokenManager.getProfileToken() != nil else { return }
        await sensorManager.resumeSensors()
    }
}
