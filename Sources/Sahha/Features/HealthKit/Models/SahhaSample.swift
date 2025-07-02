import Foundation

public struct SahhaSample: Comparable, Codable {
    public var id: String
    public var category: String
    public var type: String
    public var value: Double
    public var unit: String
    public var startDateTime: Date
    public var endDateTime: Date
    public var recordingMethod: String
    public var source: String
    public var stats: [SahhaStat]
    
    public static func < (lhs: SahhaSample, rhs: SahhaSample) -> Bool {
        lhs.startDateTime < rhs.startDateTime
    }
}
