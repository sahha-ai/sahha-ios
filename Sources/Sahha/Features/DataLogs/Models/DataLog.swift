import Foundation

struct DataLog: DataLogType {
    var parentId: String?
    var dataType: String
    var value: Double
    var source: String
    var recordingMethod: DataLogRecordingMethod
    var deviceType: String
    var startDate: Date
    var endDate: Date
    var additionalProperties: String?
}
