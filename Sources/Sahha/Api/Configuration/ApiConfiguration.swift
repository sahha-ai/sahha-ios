import Foundation

enum ApiConfiguration {
    static func baseURL() async throws -> String {
        let env = await ConfigurationStore.shared.getEnvironment()
        guard let environment = env else { throw SahhaError.notConfigured }

        switch environment {
        case .development: return "https://development-api.sahha.ai/api"
        case .sandbox:     return "https://sandbox-api.sahha.ai/api"
        case .production:  return "https://api.sahha.ai/api"
        }
    }
}
