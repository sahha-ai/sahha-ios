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

extension DataLogType {
    var id: UUID {
        UUIDFactory.v5(from: [
            dataType,
            source,
            deviceType,
            startDate.isoDateTime,
            endDate.isoDateTime
        ])
    }
    
    func toRequest(deviceInfo: DeviceInfoRequest) -> DataLogRequest {
        DataLogRequest(
            id: id.uuidString,
            parentId: parentId,
            logType: "",
            dataType: dataType,
            value: value,
            unit: "",
            source: source,
            recordingMethod: recordingMethod.stringValue,
            deviceId: deviceInfo.deviceId,
            deviceType: deviceInfo.deviceType,
            startDateTime: startDate.isoDateTime,
            endDateTime: endDate.isoDateTime,
            postDateTime: Date().isoDateTime,
            additionalProperties: additionalProperties
        )
    }
}
