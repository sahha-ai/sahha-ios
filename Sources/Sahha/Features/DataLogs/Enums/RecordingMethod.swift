enum RecordingMethod: Int, Codable, Sendable {
    case unknown
    case manual
    case automatic

    var stringValue: String {
        switch self {
        case .unknown: return "unknown"
        case .manual: return "manual_entry"
        case .automatic: return "automatically_recorded"
        }
    }
}
