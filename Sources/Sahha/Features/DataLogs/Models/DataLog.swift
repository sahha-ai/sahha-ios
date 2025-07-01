import Foundation

// Future Mixed Types: Add a type property to DataLog and implement custom decoding if batches will contain multiple subclass types:
// Decoding would then use a factory based on type, but this can be added when the need arises.

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
    
    init(parentId: String?, logType: LogType, dataType: String, value: Double, unit: String, source: String, recordingMethod: RecordingMethod, deviceType: String, startDate: Date, endDate: Date, additionalProperties: [String: String]?) {
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
        case parentId, logType, dataType, value, unit, source, recordingMethod, deviceType, startDate, endDate, additionalProperties
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        parentId = try container.decodeIfPresent(String.self, forKey: .parentId)
        logType = try container.decode(LogType.self, forKey: .logType)
        dataType = try container.decode(String.self, forKey: .dataType)
        value = try container.decode(Double.self, forKey: .value)
        unit = try container.decode(String.self, forKey: .unit)
        source = try container.decode(String.self, forKey: .source)
        recordingMethod = try container.decode(RecordingMethod.self, forKey: .recordingMethod)
        deviceType = try container.decode(String.self, forKey: .deviceType)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        additionalProperties = try container.decodeIfPresent([String: String].self, forKey: .additionalProperties)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
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
    
    var id: String {
        let components = [dataType, source, deviceType, startDate.isoDateTime, endDate.isoDateTime]
        return UUIDFactory.v5(from: components).uuidString
    }
}
