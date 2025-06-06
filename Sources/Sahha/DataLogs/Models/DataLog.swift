import Foundation

struct DataLog: Codable, Sendable, Equatable {
    var parentId: String?
    var dataType: String
    var value: Double
    var source: String
    var recordingMethod: RecordingMethod
    var deviceType: String
    var startDateTime: Date
    var endDateTime: Date
    var additionalProperties: [String: String]?
}
