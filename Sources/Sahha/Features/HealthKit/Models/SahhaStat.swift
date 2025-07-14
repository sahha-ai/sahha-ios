import Foundation
import HealthKit

public struct SahhaStat: Comparable, Codable, Sendable {
    public var id: String = UUID().uuidString
    public var category: String
    public var type: String
    public var aggregation: String
    public var periodicity: String
    public var value: Double
    public var unit: String
    public var startDateTime: Date
    public var endDateTime: Date
    public var sources: [String]
    
    public static func < (lhs: SahhaStat, rhs: SahhaStat) -> Bool {
        lhs.value < rhs.value
    }
}

