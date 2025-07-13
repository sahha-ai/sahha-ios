import Foundation

extension Date {
    var isoDate: String {
        DateFormatter.isoDate.string(from: self)
    }
    
    var isoDateTime: String {
        DateFormatter.isoDateTimeWithOffset.string(from: self)
    }
    
    var utcOffset: String {
        DateFormatter.utcOffsetOnly.string(from: self)
    }
    
    var timestamp: String {
        DateFormatter.timestamp.string(from: self)
    }
    
    var timestampMillis: String {
        DateFormatter.timestampMillis.string(from: self)
    }
}
