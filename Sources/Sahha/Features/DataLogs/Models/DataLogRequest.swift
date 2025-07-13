import Foundation

open class DataLogRequest: Encodable, @unchecked Sendable {
    var id: String
    var parentId: String?
    var logType: String
    var dataType: String
    var value: Double
    var unit: String
    var source: String
    var recordingMethod: String
    var deviceType: String
    var startDate: Date
    var endDate: Date
    var additionalProperties: String?
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
        startDate: Date,
        endDate: Date,
        additionalProperties: String? = nil,
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
        self.startDate = startDate
        self.endDate = endDate
        self.additionalProperties = additionalProperties
        self.deviceId = deviceId
        self.postDateTime = Date().isoDateTime
    }

    private enum CodingKeys: String, CodingKey {
        case id, parentId, logType, dataType, value, unit, source,
            recordingMethod, deviceType, startDate, endDate,
            additionalProperties, deviceId, postDateTime
    }

    required public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        parentId = try c.decodeIfPresent(String.self, forKey: .parentId)
        logType = try c.decode(String.self, forKey: .logType)
        dataType = try c.decode(String.self, forKey: .dataType)
        value = try c.decode(Double.self, forKey: .value)
        unit = try c.decode(String.self, forKey: .unit)
        source = try c.decode(String.self, forKey: .source)
        recordingMethod = try c.decode(String.self, forKey: .recordingMethod)
        deviceType = try c.decode(String.self, forKey: .deviceType)
        startDate = try c.decode(Date.self, forKey: .startDate)
        endDate = try c.decode(Date.self, forKey: .endDate)
        additionalProperties = try c.decodeIfPresent(String.self, forKey: .additionalProperties)
        deviceId = try c.decode(String.self, forKey: .deviceId)
        postDateTime = try c.decode(String.self, forKey: .postDateTime)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(parentId, forKey: .parentId)
        try c.encode(logType, forKey: .logType)
        try c.encode(dataType, forKey: .dataType)
        try c.encode(value, forKey: .value)
        try c.encode(unit, forKey: .unit)
        try c.encode(source, forKey: .source)
        try c.encode(recordingMethod, forKey: .recordingMethod)
        try c.encode(deviceType, forKey: .deviceType)
        try c.encode(startDate, forKey: .startDate)
        try c.encode(endDate, forKey: .endDate)
        try c.encodeIfPresent(additionalProperties, forKey: .additionalProperties)
        try c.encode(postDateTime, forKey: .postDateTime)
        try c.encode(deviceId, forKey: .deviceId)
    }
}
