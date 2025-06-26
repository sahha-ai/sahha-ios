import Foundation

enum DataLogError: Error, LocalizedError {
    case maxUploadRetriesExceeded
    
    var errorDescription: String? {
        switch self {
        case .maxUploadRetriesExceeded:
            return "Max data log upload retries exceeded. Requeueing batch."
        }
    }
}
