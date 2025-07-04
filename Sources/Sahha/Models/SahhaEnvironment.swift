public enum SahhaEnvironment: String, Sendable {
    case development
    case sandbox
    case production
}

extension SahhaEnvironment {
    var baseURL: String {
        switch self {
        case .development: return "https://development-api.sahha.ai/api"
        case .sandbox: return "https://sandbox-api.sahha.ai/api"
        case .production: return "https://api.sahha.ai/api"
        }
    }
}
