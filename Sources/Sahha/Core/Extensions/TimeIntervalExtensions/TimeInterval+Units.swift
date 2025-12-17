import Foundation

extension TimeInterval {
    static func days(_ value: Double) -> TimeInterval {
        return value * 86400  // 24 * 60 * 60
    }
    
    static func hours(_ value: Double) -> TimeInterval {
        return value * 3600
    }
    
    static func minutes(_ value: Double) -> TimeInterval {
        return value * 60
    }
    
    static func seconds(_ value: Double) -> TimeInterval {
        value
    }
}
