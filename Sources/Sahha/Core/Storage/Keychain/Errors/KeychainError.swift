import Foundation

enum KeychainError: Error, LocalizedError {
    case encodingFailed
    case decodingFailed
    case saveFailed(String)
    case deleteFailed(String)
    case itemNotFound

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode data for Keychain storage."
        case .decodingFailed:
            return "Failed to decode data from Keychain."
        case .saveFailed(let message):
            return "Failed to save to Keychain: \(message)."
        case .deleteFailed(let message):
            return "Failed to delete from Keychain: \(message)."
        case .itemNotFound:
            return "No item found in Keychain."
        }
    }
}
