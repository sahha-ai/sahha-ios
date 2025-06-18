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
