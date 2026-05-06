import HealthKit

/// Normaliser for HKCategoryTypeIdentifier.progesteroneTestResult → Tag.
///
/// value maps to the platform-agnostic ProgesteroneTestEnum snake_case string (aligned with Android):
///   "inconclusive"  (HK: indeterminate)
///   "negative"
///   "positive"
final class HKProgesteroneTestToTagNormaliser: HKSampleToTagNormaliserProtocol {
    func normalise(_ sample: HKSample, profileId: String?) -> [Tag] {
        guard let sample = sample as? HKCategorySample,
            let sensor = sample.categoryType.sahhaSensor
        else { return [] }

        let value = HKCategoryValueProgesteroneTestResult(rawValue: sample.value)?.progesteroneTestValue ?? ProgesteroneTestEnum.inconclusive.value

        return [
            Tag(
                profileId: profileId,
                type: .event,
                startDateTime: sample.startDate,
                name: sensor.rawValue,
                category: "reproductive",
                value: value,
                source: sample.sourceId
            )
        ]
    }
}
