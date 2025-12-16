import Foundation

public struct SensorQueryResult: Sendable {
    public enum Status: String, Sendable {
        case success
        case noSamples
        case skippedCircuitOpen
        case failed
    }

    public let sensor: SahhaSensor
    public let status: Status
    public let samplesFetched: Int
    public let logsProduced: Int
    public let anchorUpdated: Bool
    public let message: String?
    public let errorDescription: String?

    public init(
        sensor: SahhaSensor,
        status: Status,
        samplesFetched: Int,
        logsProduced: Int,
        anchorUpdated: Bool,
        message: String? = nil,
        errorDescription: String? = nil
    ) {
        self.sensor = sensor
        self.status = status
        self.samplesFetched = samplesFetched
        self.logsProduced = logsProduced
        self.anchorUpdated = anchorUpdated
        self.message = message
        self.errorDescription = errorDescription
    }
}

public struct PostSensorDataResult: Sendable {
    public let sensorResults: [SensorQueryResult]
    public let errorDescription: String?
    public let timestamp: Date

    public init(sensorResults: [SensorQueryResult], errorDescription: String? = nil, timestamp: Date = Date()) {
        self.sensorResults = sensorResults
        self.errorDescription = errorDescription
        self.timestamp = timestamp
    }

    public var totalSensors: Int { sensorResults.count }
    public var totalSamples: Int { sensorResults.reduce(0) { $0 + $1.samplesFetched } }
    public var totalLogs: Int { sensorResults.reduce(0) { $0 + $1.logsProduced } }
    public var successfulSensors: Int { sensorResults.filter { $0.status == .success || $0.status == .noSamples }.count }
    public var failedSensors: Int { sensorResults.filter { $0.status == .failed }.count }
    public var skippedSensors: Int { sensorResults.filter { $0.status == .skippedCircuitOpen }.count }

    public var hasFailures: Bool { failedSensors > 0 }
    public var hasSkips: Bool { skippedSensors > 0 }

    public static func failure(_ error: Error) -> PostSensorDataResult {
        return PostSensorDataResult(sensorResults: [], errorDescription: error.localizedDescription)
    }
}

