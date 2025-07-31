final class PostInsightsLifecycleListener: LifecycleListener {
    private let healthKitManager: HealthKitManagerProtocol

    init(healthKitManager: HealthKitManagerProtocol) {
        self.healthKitManager = healthKitManager
    }

    func handleLifecycleEvent(_ event: LifecycleEvent) async {
        await healthKitManager.postInsights()
    }
}
