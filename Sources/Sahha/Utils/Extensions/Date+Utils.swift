import Foundation

extension DateFormatter {
    static let isoDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    static let isoDateTimeWithOffset: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSZZZZZ"
        return formatter
    }()
    
    static let utcOffsetOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "ZZZZZ"
        return formatter
    }()
    
    static let hhmmss: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmmss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    static let hhmmssMillis: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmmss.SSS"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

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
        DateFormatter.hhmmss.string(from: self)
    }
    
    var timestampMillis: String {
        DateFormatter.hhmmssMillis.string(from: self)
    }
    
    func secondsSinceStartOfDay(calendar: Calendar = .current) -> Int {
        let startOfDay = calendar.startOfDay(for: self)
        return Int(self.timeIntervalSince(startOfDay))
    }
}
