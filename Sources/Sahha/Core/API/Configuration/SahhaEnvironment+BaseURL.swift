import Foundation

extension SahhaEnvironment {
    var baseURL: URL {
        switch self {
        case .development: return URL(string: "https://54c1-64-246-88-164.ngrok-free.app/api")!
        case .sandbox: return URL(string: "https://sandbox-api.sahha.ai/api")!
        case .production: return URL(string: "https://api.sahha.ai/api")!
        }
    }
}
