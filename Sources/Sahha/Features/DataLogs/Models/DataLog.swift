import Foundation

open class DataLog: Codable, @unchecked Sendable {
    var parentId: String?
    var logType: LogType
    var dataType: String
    var value: Double
    var unit: String
    var source: String
    var recordingMethod: RecordingMethod
    var deviceType: String
    var startDate: Date
    var endDate: Date
    var additionalProperties: [String: String]?

    init(
        parentId: String? = nil,
        logType: LogType,
        dataType: String,
        value: Double,
        unit: String,
        source: String,
        recordingMethod: RecordingMethod,
        deviceType: String,
        startDate: Date,
        endDate: Date,
        additionalProperties: [String: String]? = nil
    ) {
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
    }
    
    var id: String {
        let components = [
            dataType, source, deviceType,
            startDate.isoDateTime, endDate.isoDateTime,
        ]
        return UUIDFactory.v5(from: components).uuidString
    }

    private enum CodingKeys: String, CodingKey {
        case parentId, logType, dataType, value, unit, source,
            recordingMethod, deviceType, startDate, endDate,
            additionalProperties
    }

    required public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        parentId = try c.decodeIfPresent(String.self, forKey: .parentId)
        logType = try c.decode(LogType.self, forKey: .logType)
        dataType = try c.decode(String.self, forKey: .dataType)
        value = try c.decode(Double.self, forKey: .value)
        unit = try c.decode(String.self, forKey: .unit)
        source = try c.decode(String.self, forKey: .source)
        recordingMethod = try c.decode(RecordingMethod.self, forKey: .recordingMethod)
        deviceType = try c.decode(String.self, forKey: .deviceType)
        startDate = try c.decode(Date.self, forKey: .startDate)
        endDate = try c.decode(Date.self, forKey: .endDate)
        additionalProperties = try c.decodeIfPresent(
            [String: String].self,
            forKey: .additionalProperties
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
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
    }
}
