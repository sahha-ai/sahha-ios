import Foundation

open class DataLogRequest: Codable, @unchecked Sendable {
    var id: String
    var parentId: String?
    var logType: String
    var dataType: String
    var value: Double
    var unit: String
    var source: String
    var recordingMethod: String
    var deviceType: String
    var startDateTime: String
    var endDateTime: String
    var additionalProperties: AdditionalProperties?
    var postDateTime: String
    var deviceId: String

    init(
        id: String,
        parentId: String? = nil,
        logType: String,
        dataType: String,
        value: Double,
        unit: String,
        source: String,
        recordingMethod: String,
        deviceType: String,
        startDateTime: String,
        endDateTime: String,
        additionalProperties: AdditionalProperties? = nil,
        deviceId: String
    ) {
        self.id = id
        self.parentId = parentId
        self.logType = logType
        self.dataType = dataType
        self.value = value
        self.unit = unit
        self.source = source
        self.recordingMethod = recordingMethod
        self.deviceType = deviceType
        self.startDateTime = startDateTime
        self.endDateTime = endDateTime
        self.additionalProperties = additionalProperties
        self.deviceId = deviceId
        self.postDateTime = Date().isoDateTime
    }

    private enum CodingKeys: String, CodingKey {
        case id, parentId, logType, dataType, value, unit, source,
            recordingMethod, deviceType, startDateTime, endDateTime,
            additionalProperties, deviceId, postDateTime
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        parentId = try container.decodeIfPresent(String.self, forKey: .parentId)
        logType = try container.decode(String.self, forKey: .logType)
        dataType = try container.decode(String.self, forKey: .dataType)
        value = try container.decode(Double.self, forKey: .value)
        unit = try container.decode(String.self, forKey: .unit)
        source = try container.decode(String.self, forKey: .source)
        recordingMethod = try container.decode(String.self, forKey: .recordingMethod)
        deviceType = try container.decode(String.self, forKey: .deviceType)
        startDateTime = try container.decode(String.self, forKey: .startDateTime)
        endDateTime = try container.decode(String.self, forKey: .endDateTime)
        additionalProperties = try container.decodeIfPresent(AdditionalProperties.self, forKey: .additionalProperties)
        deviceId = try container.decode(String.self, forKey: .deviceId)
        postDateTime = try container.decode(String.self, forKey: .postDateTime)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(parentId, forKey: .parentId)
        try container.encode(logType, forKey: .logType)
        try container.encode(dataType, forKey: .dataType)
        try container.encode(value, forKey: .value)
        try container.encode(unit, forKey: .unit)
        try container.encode(source, forKey: .source)
        try container.encode(recordingMethod, forKey: .recordingMethod)
        try container.encode(deviceType, forKey: .deviceType)
        try container.encode(startDateTime, forKey: .startDateTime)
        try container.encode(endDateTime, forKey: .endDateTime)
        try container.encodeIfPresent(additionalProperties, forKey: .additionalProperties)
        try container.encode(postDateTime, forKey: .postDateTime)
        try container.encode(deviceId, forKey: .deviceId)
    }
}
