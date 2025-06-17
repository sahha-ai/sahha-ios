import Foundation

enum DataLogType: String, Codable {
    case demographic
    case sleep
    case activity
    case device
    case heart
    case blood
    case oxygen
    case energy
    case temperature
    case body
    case exercise
}

enum DataLogRecordingMethod: Int, Codable, Sendable {
    case unknown = 0
    case manual = 1
    case automatic = 2
    
    var stringValue: String {
        switch self {
        case .unknown: return "RECORDING_METHOD_UNKNOWN"
        case .manual: return "RECORDING_METHOD_MANUAL"
        case .automatic: return "RECORDING_METHOD_AUTOMATICALLY_RECORDED"
        }
    }
}

struct DataLog: Codable, Sendable, Equatable {
    var parentId: String?
    var dataType: String
    var value: Double
    var source: String
    var recordingMethod: DataLogRecordingMethod
    var deviceType: String
    var startDate: Date
    var endDate: Date
    var additionalProperties: String? // TODO
}

extension DataLog {
    var id: UUID {
        UUIDFactory.v5(from: [
            dataType,
            source,
            deviceType,
            startDate.isoDateTime,
            endDate.isoDateTime
        ])
    }
}
