import Foundation

enum DecodingError: LocalizedError {
    case failed(Error)

    var errorDescription: String? {
        switch self {
        case .failed(let error): "Decoding failed: \(error)"
        }
    }
}
