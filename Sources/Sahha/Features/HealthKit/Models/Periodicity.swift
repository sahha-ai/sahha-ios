import Foundation

enum Periodicity: String {
    case hourly
    case daily
}

extension Periodicity {
    var windowDuration: TimeInterval {
        switch self {
        case .hourly: return 3_600
        case .daily:  return 86_400
        }
    }
}
