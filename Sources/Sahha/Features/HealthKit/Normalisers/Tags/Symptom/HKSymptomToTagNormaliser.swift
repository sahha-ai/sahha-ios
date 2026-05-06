import HealthKit

/// Normaliser for all 38 health symptom category types → Tag.
///
/// Despite some symptoms being part of HealthKit's "reproductive health" UI grouping,
/// this normaliser covers the full symptom surface — cardiac, respiratory, GI,
/// neurological, mood, dermatological, and reproductive — because they all share
/// the same underlying `HKCategoryValueSeverity` shape.
///
/// value is the HKCategoryValueSeverity mapped to a snake_case string:
///   "unknown"      (HK: unspecified — present but not graded)
///   "not_present"  (HK: notPresent — explicitly logged as absent)
///   "mild"
///   "moderate"
///   "severe"
///
/// Tag name is always `sensor.rawValue`. Absence is communicated by `value: "not_present"`,
/// not by mutating the name.
final class HKSymptomToTagNormaliser: HKSampleToTagNormaliserProtocol {
    func normalise(_ sample: HKSample, profileId: String?) -> [Tag] {
        guard let sample = sample as? HKCategorySample,
              let sensor = sample.categoryType.sahhaSensor
        else { return [] }

        let value = HKCategoryValueSeverity(rawValue: sample.value)?.severityValue ?? SeverityEnum.unknown.value

        return [
            Tag(
                profileId: profileId,
                type: .event,
                startDateTime: sample.startDate,
                name: sensor.rawValue,
                category: "symptom",
                value: value,
                source: sample.sourceId
            )
        ]
    }
}
