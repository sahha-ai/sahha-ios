import Foundation
import HealthKit

typealias MetadataMapper = @Sendable (Any) -> String?
typealias MetadataMapping = [String: (propertyName: String, mapper: MetadataMapper)]

func extractAdditionalProperties(from sample: HKSample, using mappings: MetadataMapping) -> [String: String]? {
    guard let metadata = sample.metadata else {return nil}

    var additionalProperties: [String: String] = [:]
    for (key, mapping) in mappings {
        if let value = metadata[key], let stringValue = mapping.mapper(value) {
            additionalProperties[mapping.propertyName] = stringValue
        }
    }
    return additionalProperties.isEmpty ? nil : additionalProperties
}

protocol StringRepresentable {
    var stringValue: String { get }
}

func enumMapper<T: RawRepresentable & StringRepresentable>(for type: T.Type) -> MetadataMapper where T.RawValue == Int {
    return { value in
        guard let number = value as? NSNumber,
              let enumValue = T(rawValue: number.intValue)
        else {
            return nil
        }
        return enumValue.stringValue
    }
}
