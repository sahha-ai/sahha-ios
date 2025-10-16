enum RecordingMethod: Int, Codable, Sendable {
    case unknown
    case manual
    case automatic

    var stringValue: String {
        switch self {
        case .unknown: return "RECORDING_METHOD_UNKNOWN"
        case .manual: return "RECORDING_METHOD_MANUAL"
        case .automatic: return "RECORDING_METHOD_AUTOMATICALLY_RECORDED"
        }
    }
}
