import Foundation

extension TimeInterval {
    static func hours(_ value: Double) -> TimeInterval {
        return value * 3600
    }
    
    static func minutes(_ value: Double) -> TimeInterval {
        return value * 60
    }
}
