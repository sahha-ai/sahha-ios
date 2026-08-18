import Foundation

/// Thin lifecycle delegate: the check itself lives in `SensorHealthCheckService`,
/// which the authenticated bring-up tail also drives directly. The listener stays
/// registered for `.app_foreground` only — `.app_resume` is explicitly rejected
/// as a trigger because it fires on every interruption dismissal, including the
/// HealthKit permission sheet.
final class SensorHealthCheckLifecycleListener: LifecycleListener, @unchecked Sendable {
    private let healthCheckService: SensorHealthCheckServiceProtocol

    init(healthCheckService: SensorHealthCheckServiceProtocol) {
        self.healthCheckService = healthCheckService
    }

    func handleLifecycleEvent(_ event: LifecycleEvent) async {
        let result = await healthCheckService.runHealthCheck()

        if !result.allHealthy {
            Sahha.log("[SensorHealthCheck] Re-registered \(result.sensorsReRegistered.count) observer(s), \(result.failures.count) failure(s)")
        }
    }

    func getLatestResult() async -> SensorHealthCheckResult? {
        await healthCheckService.getLatestResult()
    }
}
