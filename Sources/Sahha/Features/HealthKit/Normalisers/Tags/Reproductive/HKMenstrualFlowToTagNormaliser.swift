import HealthKit

/// Normaliser for HKCategoryTypeIdentifier.menstrualFlow → Tag.
///
/// value maps to the platform-agnostic MenstrualFlowEnum snake_case string (aligned with Android):
///   "unknown"      (HK: unspecified — flow occurred, level not graded)
///   "not_present"  (HK: none — explicitly logged as no flow today)
///   "light"
///   "medium"
///   "heavy"
///
/// additionalProperties["cycle_start"] — true if this sample marks the
/// start of a new menstrual cycle (HKMetadataKeyMenstrualCycleStart).
final class HKMenstrualFlowToTagNormaliser: HKSampleToTagNormaliserProtocol {
    func normalise(_ sample: HKSample, profileId: String?) -> [Tag] {
        guard let sample = sample as? HKCategorySample,
            let sensor = sample.categoryType.sahhaSensor
        else { return [] }

        let value = HKCategoryValueMenstrualFlow(rawValue: sample.value)?.menstrualFlowValue ?? MenstrualFlowEnum.unknown.value

        var properties: [String: AnyCodable] = [:]
        if let isCycleStart = sample.metadata?[HKMetadataKeyMenstrualCycleStart] as? Bool {
            properties["cycle_start"] = AnyCodable(String(isCycleStart))
        }

        let additionalProperties: [String: AnyCodable]? = properties.isEmpty ? nil : properties

        return [
            Tag(
                profileId: profileId,
                type: .event,
                startDateTime: sample.startDate,
                name: sensor.rawValue,
                category: "reproductive",
                value: value,
                source: sample.sourceId,
                additionalProperties: additionalProperties
            )
        ]
    }
}
