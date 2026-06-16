import Foundation

extension Date {
    var isoDate: String {
        DateFormatter.isoDate.string(from: self)
    }
    
    var isoDateTime: String {
        DateFormatter.isoDateTime.string(from: self)
    }

    var isoDateTimeWithoutTimeZone: String {
        DateFormatter.isoDateTimeWithoutTimeZone.string(from: self)
    }
    
    var uuidDateTime: String {
        DateFormatter.uuidDateTime.string(from: self)
    }

    var utcOffset: String {
        DateFormatter.utcOffset.string(from: self)
    }
}
