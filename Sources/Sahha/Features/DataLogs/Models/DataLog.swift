import Foundation

open class DataLog: Codable, @unchecked Sendable {
    let id: String
    var parentId: String?
    var logType: DataLogType
    var dataType: String
    var value: Double
    var unit: String
    var source: String
    var recordingMethod: RecordingMethod
    var deviceType: String
    var startDate: Date
    var endDate: Date
    var additionalProperties: AdditionalProperties?

    init(
        id: String? = nil,
        parentId: String? = nil,
        logType: DataLogType,
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
        if let id {
            self.id = id
        } else {
            let components = [dataType, source, deviceType, startDate.isoDateTime, endDate.isoDateTime]
            self.id = UUIDFactory.v5(from: components).uuidString
        }
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

    private enum CodingKeys: String, CodingKey {
        case id, parentId, logType, dataType, value, unit, source,
            recordingMethod, deviceType, startDate, endDate,
            additionalProperties
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        parentId = try container.decodeIfPresent(String.self, forKey: .parentId)
        logType = try container.decode(DataLogType.self, forKey: .logType)
        dataType = try container.decode(String.self, forKey: .dataType)
        value = try container.decode(Double.self, forKey: .value)
        unit = try container.decode(String.self, forKey: .unit)
        source = try container.decode(String.self, forKey: .source)
        recordingMethod = try container.decode(RecordingMethod.self, forKey: .recordingMethod)
        deviceType = try container.decode(String.self, forKey: .deviceType)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        additionalProperties = try container.decodeIfPresent(AdditionalProperties.self, forKey: .additionalProperties)
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
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encodeIfPresent(additionalProperties, forKey: .additionalProperties)
    }
}
