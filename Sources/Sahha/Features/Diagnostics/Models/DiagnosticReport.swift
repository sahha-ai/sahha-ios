import Foundation

/// Pipeline health metadata snapshot — contains NO health data values by design (HIPAA/GDPR).
public struct DiagnosticReport: Codable, Sendable {
    public let timestamp: Date
    public let sdkVersion: String
    public let deviceModel: String
    public let system: String
    public let systemVersion: String
    public let appId: String

    public let enabledSensors: [String]
    public let sensorStatuses: [String: String]
    public let queues: Queues
    public let circuitBreakerState: String
    public let circuitBreakerFailures: Int
    public let isNetworkConnected: Bool

    public struct Queues: Codable, Sendable {
        public let dataLog: QueueSnapshot
        public let tag: QueueSnapshot
    }

    public struct QueueSnapshot: Codable, Sendable {
        public let totalBatches: Int
        public let totalItems: Int
        public let failedBatches: Int
        public let oldestBatchAge: TimeInterval?
    }
}
