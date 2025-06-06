import Foundation

extension TimeInterval {
    static func minutes(_ value: Int) -> TimeInterval {
        return Double(value * 60)
    }
}

