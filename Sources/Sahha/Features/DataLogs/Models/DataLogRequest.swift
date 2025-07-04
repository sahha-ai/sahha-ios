import Foundation

open class DataLogRequest: DataLog, @unchecked Sendable {
    var postDateTime: String
    var deviceId: String

    init(
        parentId: String?,
        logType: LogType,
        dataType: String,
        value: Double,
        unit: String,
        source: String,
        recordingMethod: RecordingMethod,
        deviceType: String,
        startDate: Date,
        endDate: Date,
        additionalProperties: [String: String]?,
        postDateTime: String,
        deviceId: String
    ) {
        self.postDateTime = postDateTime
        self.deviceId = deviceId
        super.init(
            parentId: parentId,
            logType: logType,
            dataType: dataType,
            value: value,
            unit: unit,
            source: source,
            recordingMethod: recordingMethod,
            deviceType: deviceType,
            startDate: startDate,
            endDate: endDate,
            additionalProperties: additionalProperties
        )
    }

    private enum CodingKeys: String, CodingKey {
        case postDateTime, deviceId
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        postDateTime = try container.decode(String.self, forKey: .postDateTime)
        deviceId = try container.decode(String.self, forKey: .deviceId)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(postDateTime, forKey: .postDateTime)
        try container.encode(deviceId, forKey: .deviceId)
        try super.encode(to: encoder)
    }

    static func create(from dataLog: DataLog, deviceInformation: DeviceInformation) -> DataLogRequest {
        DataLogRequest(
            parentId: dataLog.parentId,
            logType: dataLog.logType,
            dataType: dataLog.dataType,
            value: dataLog.value,
            unit: dataLog.unit,
            source: dataLog.source,
            recordingMethod: dataLog.recordingMethod,
            deviceType: dataLog.deviceType,
            startDate: dataLog.startDate,
            endDate: dataLog.endDate,
            additionalProperties: dataLog.additionalProperties,
            postDateTime: Date().isoDateTime,
            deviceId: deviceInformation.deviceId
        )
    }
}
