import HealthKit

enum DataLogAdditionalPropertiesKey: Int, Codable {
    case measurementLocation = 0
    case measurementMethod = 1
    case motionContext = 2
    case relationToMeal = 3
    case totalDistance = 4
    case totalEnergyBurned = 5
}

enum BloodRelationToMeal: Int {
    case before_meal = 0, after_meal, unknown
}

struct DataLogAdditionalProperties: Codable, Equatable, Sendable {
    private(set) var storage: [DataLogAdditionalPropertiesKey: String] = [:]

    subscript(key: DataLogAdditionalPropertiesKey) -> String? {
        get { storage[key] }
        set { storage[key] = newValue }
    }

    var isEmpty: Bool { storage.isEmpty }

    func serialise() -> String? {
        guard !storage.isEmpty else { return nil }
        return storage.map { "\($0.key.rawValue):\($0.value)" }
                      .joined(separator: ",")
                      .wrapped()
    }

    static func deserialise(_ string: String) -> DataLogAdditionalProperties? {
        guard string.hasPrefix("[") && string.hasSuffix("]") else { return nil }
        let content = string.dropFirst().dropLast()
        var props = DataLogAdditionalProperties()

        for entry in content.split(separator: ",") {
            let pair = entry.split(separator: ":", maxSplits: 1)
            guard pair.count == 2,
                  let key = DataLogAdditionalPropertiesKey(rawValue: Int(pair[0])!) else { continue }
            props[key] = String(pair[1])
        }

        return props.isEmpty ? nil : props
    }

    func toRequestPayload() -> [String: String]? {
        guard !storage.isEmpty else { return nil }
        var api: [String: String] = [:]

        for (key, rawValue) in storage {
            let resolved: String?
            switch key {
            case .measurementLocation:
                resolved = convert(rawValue, as: HKHeartRateSensorLocation.self)
            case .measurementMethod:
                resolved = convert(rawValue, as: HKVO2MaxTestType.self)
            case .motionContext:
                resolved = convert(rawValue, as: HKHeartRateMotionContext.self)
            case .relationToMeal:
                resolved = convert(rawValue, as: HKBloodGlucoseMealTime.self)
            case .totalDistance, .totalEnergyBurned:
                resolved = mapRelationToMeal(rawValue)
            }
            if let val = resolved {
                api["\(key)".camelToSnake] = val
            }
        }

        return api.isEmpty ? nil : api
    }
    
    private func mapRelationToMeal(_ raw: String) -> String? {
        guard let intVal = Int(raw),
              let hkValue = HKBloodGlucoseMealTime(rawValue: intVal) else { return nil }

        let relation: BloodRelationToMeal
        switch hkValue {
        case .preprandial:   relation = .before_meal
        case .postprandial:  relation = .after_meal
        default:             relation = .unknown
        }
        return "\(relation)".camelToSnake
    }

    private func convert<T: RawRepresentable>(_ raw: String, as type: T.Type) -> String? where T.RawValue == Int {
        guard let intVal = Int(raw),
              let enumVal = T(rawValue: intVal) else { return nil }
        return "\(enumVal)".camelToSnake
    }
}

private extension String {
    func wrapped() -> String { "[\(self)]" }
}
