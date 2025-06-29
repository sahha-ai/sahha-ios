import Foundation

enum DataLogError: Error, LocalizedError {
    case maxUploadRetriesExceeded
    case processorNotAcceptingData
    
    var errorDescription: String? {
        switch self {
        case .maxUploadRetriesExceeded:
            return "Max data log upload retries exceeded. Requeueing batch."
            case .processorNotAcceptingData:
            return "Data log processor is not accepting data."
        }
    }
}
