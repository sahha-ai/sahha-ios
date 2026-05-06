import Foundation

extension SahhaEnvironment {
    var baseURL: URL {
        switch self {
        case .development: return URL(string: "https:development-api.sahha.ai/api")!
        case .sandbox: return URL(string: "https://sandbox-api.sahha.ai/api")!
        case .production: return URL(string: "https://api.sahha.ai/api")!
        }
    }
}
