import Foundation

struct SensorHealthCheckResult: Sendable {
    let timestamp: Date
    let sensorsChecked: Set<SahhaSensor>
    let sensorsReRegistered: Set<SahhaSensor>
    let failures: [SahhaSensor: String]

    var allHealthy: Bool {
        sensorsReRegistered.isEmpty && failures.isEmpty
    }
}
