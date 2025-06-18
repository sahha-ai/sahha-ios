import Foundation

protocol DataLogType: Codable, Sendable, Equatable {
    var parentId: String? {get set}
    var dataType: String {get set}
    var value: Double {get set}
    var source: String {get set}
    var recordingMethod: DataLogRecordingMethod {get set}
    var deviceType: String  {get set}
    var startDate: Date {get set}
    var endDate: Date {get set}
    var additionalProperties: String? {get set}
}
