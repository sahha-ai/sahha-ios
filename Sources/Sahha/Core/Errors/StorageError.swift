import Foundation

enum StorageError: LocalizedError {
  case noData
  case unexpectedData
  case unhandledError(status: OSStatus)
  case encodingError(Error)
  case decodingError(Error)

  public var errorDescription: String? {
    switch self {
    case .noData:
      return "No stored data was found."
    case .unexpectedData:
      return "Stored data was in an unexpected format."
    case .unhandledError(let status):
      return "An internal storage error occurred (code \(status))."
    case .encodingError:
      return "Failed to encode data for storage."
    case .decodingError:
      return "Failed to decode stored data."
    }
  }
}
