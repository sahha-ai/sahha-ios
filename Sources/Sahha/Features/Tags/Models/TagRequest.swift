import Foundation

/// Immutable request payload for tag delivery - all fields are constants after creation
open class TagRequest: Codable, @unchecked Sendable {
    let id: String
    let type: String
    let startDateTime: String
    let endDateTime: String?
    let name: String
    let category: String?
    let value: String?
    let source: String
    let additionalProperties: [String: AnyCodable]?
    let postDateTime: String
    let deviceId: String

    init(
        id: String,
        type: String,
        startDateTime: String,
        endDateTime: String?,
        name: String,
        category: String?,
        value: String?,
        source: String,
        additionalProperties: [String: AnyCodable]?,
        deviceId: String
    ) {
        self.id = id
        self.type = type
        self.startDateTime = startDateTime
        self.endDateTime = endDateTime
        self.name = name
        self.category = category
        self.value = value
        self.source = source
        self.additionalProperties = additionalProperties
        self.deviceId = deviceId
        self.postDateTime = Date().isoDateTime
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, startDateTime, endDateTime, name,
            category, value, source, additionalProperties,
            deviceId, postDateTime
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        startDateTime = try container.decode(String.self, forKey: .startDateTime)
        endDateTime = try container.decodeIfPresent(String.self, forKey: .endDateTime)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        value = try container.decodeIfPresent(String.self, forKey: .value)
        source = try container.decode(String.self, forKey: .source)
        additionalProperties = try container.decodeIfPresent([String: AnyCodable].self, forKey: .additionalProperties)
        deviceId = try container.decode(String.self, forKey: .deviceId)
        postDateTime = try container.decode(String.self, forKey: .postDateTime)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(startDateTime, forKey: .startDateTime)
        try container.encodeIfPresent(endDateTime, forKey: .endDateTime)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(additionalProperties, forKey: .additionalProperties)
        try container.encode(postDateTime, forKey: .postDateTime)
        try container.encode(deviceId, forKey: .deviceId)
    }
}
