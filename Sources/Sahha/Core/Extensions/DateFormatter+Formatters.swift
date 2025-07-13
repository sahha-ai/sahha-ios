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
    
    static let timestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmmss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    static let timestampMillis: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmmss.SSS"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
