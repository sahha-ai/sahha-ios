import Foundation

/// A type-erased `Codable` value that supports JSON-compatible types.
/// Used for flexible metadata fields like `additionalProperties` on Tags.
struct AnyCodable: Codable, Sendable, Equatable, Hashable {
    let value: AnyCodableValue

    init(_ value: Any?) {
        self.value = AnyCodableValue(value)
    }

    init(_ value: String) { self.value = .string(value) }
    init(_ value: Int) { self.value = .int(value) }
    init(_ value: Double) { self.value = .double(value) }
    init(_ value: Bool) { self.value = .bool(value) }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = .null
        } else if let bool = try? container.decode(Bool.self) {
            value = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            value = .int(int)
        } else if let double = try? container.decode(Double.self) {
            value = .double(double)
        } else if let string = try? container.decode(String.self) {
            value = .string(string)
        } else if let array = try? container.decode([AnyCodable].self) {
            value = .array(array)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = .dictionary(dict)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable cannot decode value"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case .null:
            try container.encodeNil()
        case .bool(let v):
            try container.encode(v)
        case .int(let v):
            try container.encode(v)
        case .double(let v):
            try container.encode(v)
        case .string(let v):
            try container.encode(v)
        case .array(let v):
            try container.encode(v)
        case .dictionary(let v):
            try container.encode(v)
        }
    }
}

enum AnyCodableValue: Sendable, Equatable, Hashable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodable])
    case dictionary([String: AnyCodable])

    init(_ value: Any?) {
        guard let value else { self = .null; return }
        switch value {
        case let v as Bool:   self = .bool(v)
        case let v as Int:    self = .int(v)
        case let v as Double: self = .double(v)
        case let v as String: self = .string(v)
        case let v as [Any?]:
            self = .array(v.map { AnyCodable($0) })
        case let v as [String: Any?]:
            self = .dictionary(v.mapValues { AnyCodable($0) })
        default:
            self = .string(String(describing: value))
        }
    }
}
