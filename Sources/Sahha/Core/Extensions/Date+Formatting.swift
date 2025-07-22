import Foundation

extension Date {
    /// e.g. “2025-07-18”
    var isoDate: String {
        DateFormatter.isoDate.string(from: self)
    }
    
    /// e.g. “2025-07-18T14:23:45.123+12:00”
    var isoDateTime: String {
        DateFormatter.isoDateTime.string(from: self)
    }
    
    /// e.g. “+12:00”
    var utcOffset: String {
        DateFormatter.utcOffset.string(from: self)
    }
}
