import HealthKit

/// Normaliser for HKCategoryTypeIdentifier.menstrualFlow → Tag.
///
/// value maps to the platform-agnostic MenstrualFlowEnum ordinal (aligned with Android):
///   0.0 = UNKNOWN    (HK: unspecified)
///   1.0 = NONE       (HK: notPresent — flow explicitly recorded as absent)
///   2.0 = LIGHT
///   3.0 = MEDIUM
///   4.0 = HEAVY
///
/// additionalProperties["cycle_start"] — true if this sample marks the
/// start of a new menstrual cycle (HKMetadataKeyMenstrualCycleStart).
final class HKMenstrualFlowToTagNormaliser: HKSampleToTagNormaliserProtocol {
    func normalise(_ sample: HKSample) -> [Tag] {
        guard let sample = sample as? HKCategorySample,
            let sensor = sample.categoryType.sahhaSensor
        else { return [] }

        let value = HKCategoryValueMenstrualFlow(rawValue: sample.value)?.menstrualFlowValue ?? MenstrualFlowEnum.unknown.value

        var properties: [String: AnyCodable] = [:]
        if let isCycleStart = sample.metadata?[HKMetadataKeyMenstrualCycleStart] as? Bool {
            properties["cycle_start"] = AnyCodable(isCycleStart)
        }

        let additionalProperties: [String: AnyCodable]? = properties.isEmpty ? nil : properties

        return [
            Tag(
                type: .event,
                startDateTime: sample.startDate,
                name: sensor.rawValue,
                category: "reproductive",
                value: String(value),
                source: sample.sourceId,
                additionalProperties: additionalProperties
            )
        ]
    }
}
