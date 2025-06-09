import Foundation

struct DataLog: Codable, Sendable, Equatable {
    var parentId: String?
    var dataType: String
    var value: Double
    var source: String
    var recordingMethod: DataLogRecordingMethod
    var deviceType: String
    var startDateTime: Date
    var endDateTime: Date
    var additionalProperties: DataLogAdditionalProperties?
}

extension DataLog {
    static func generateId(
        dataType: String,
        source: String,
        deviceType: String,
        startDateTime: Date,
        endDateTime: Date
    ) -> UUID {
        UUIDFactory.v5(from: [
            dataType,
            source,
            deviceType,
            startDateTime.isoDateTime,
            endDateTime.isoDateTime
        ])
    }
    
    func generateId() -> UUID {
        DataLog.generateId(
            dataType: dataType,
            source: source,
            deviceType: deviceType,
            startDateTime: startDateTime,
            endDateTime: endDateTime
        )
    }
}
