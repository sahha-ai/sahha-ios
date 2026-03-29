import Foundation

/// Immutable tag entry - all fields are constants after creation for thread safety
struct Tag: Codable, Sendable {
    let id: String
    let type: TagType
    let startDateTime: Date
    let endDateTime: Date?
    let name: String
    let category: String?
    let value: String?
    let source: String
    let additionalProperties: [String: AnyCodable]?

    init(
        id: String? = nil,
        type: TagType,
        startDateTime: Date,
        endDateTime: Date? = nil,
        name: String,
        category: String? = nil,
        value: String? = nil,
        source: String,
        additionalProperties: [String: AnyCodable]? = nil
    ) {
        // Enforce: event tags must not have an endDateTime
        if type == .event {
            precondition(endDateTime == nil, "Tag of type .event must not have an endDateTime")
        }

        if let id {
            self.id = id
        } else {
            let components: [Any] = [
                type.rawValue,
                name,
                source,
                startDateTime.isoDateTime
            ]
            self.id = UUIDFactory.v5(from: components).uuidString
        }
        self.type = type
        self.startDateTime = startDateTime
        self.endDateTime = endDateTime
        self.name = name
        self.category = category
        self.value = value
        self.source = source
        self.additionalProperties = additionalProperties
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, startDateTime, endDateTime, name,
            category, value, source, additionalProperties
    }
}
