/// A persisted sensor-set anomaly found and handled during a lenient read.
///
/// `SensorStore` latches at most one of these; the authenticated bring-up drains
/// and posts it, so an anomaly found before authentication is not lost. Carries
/// only the anomalous values and counts — never the full persisted set.
enum SensorStoreAnomaly: Equatable, Sendable, CustomStringConvertible {
    /// Legacy raw values were healed via the rename table and/or unknown raw
    /// values were dropped; storage was rewritten in canonical form.
    case healedValues(renamed: [String], droppedUnknown: [String])
    /// Every decoded value was unknown; storage was left untouched (the
    /// realistic producer is a downgrade from a future SDK, whose state must
    /// not be destroyed).
    case allUnknownValues([String])
    /// The key held a value that is not Data; storage was left untouched.
    /// Only the type name is captured, never the value.
    case foreignValue(typeName: String)
    /// The key held Data the SDK could not decode; storage was left untouched.
    case undecodableData(byteCount: Int)

    var description: String {
        switch self {
        case let .healedValues(renamed, droppedUnknown):
            var parts: [String] = []
            if !renamed.isEmpty {
                parts.append("renamed \(renamed.count): \(renamed.joined(separator: ", "))")
            }
            if !droppedUnknown.isEmpty {
                parts.append("dropped \(droppedUnknown.count) unknown: \(droppedUnknown.joined(separator: ", "))")
            }
            return "Sensor store healed legacy values — \(parts.joined(separator: "; "))"
        case let .allUnknownValues(values):
            return "Sensor store held only unknown values (\(values.count)): \(values.joined(separator: ", ")) — left untouched"
        case let .foreignValue(typeName):
            return "Sensor store key held a foreign value of type \(typeName) — left untouched"
        case let .undecodableData(byteCount):
            return "Sensor store key held undecodable Data (\(byteCount) bytes) — left untouched"
        }
    }
}
