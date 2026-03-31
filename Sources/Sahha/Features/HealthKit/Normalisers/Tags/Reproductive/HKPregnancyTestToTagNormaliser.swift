import HealthKit

/// Normaliser for HKCategoryTypeIdentifier.pregnancyTestResult → Tag.
///
/// value maps to the platform-agnostic PregnancyTestEnum snake_case string (aligned with Android):
///   "inconclusive"  (HK: indeterminate)
///   "negative"
///   "positive"
final class HKPregnancyTestToTagNormaliser: HKSampleToTagNormaliserProtocol {
    func normalise(_ sample: HKSample, profileId: String?) -> [Tag] {
        guard let sample = sample as? HKCategorySample,
            let sensor = sample.categoryType.sahhaSensor
        else { return [] }

        let value = HKCategoryValuePregnancyTestResult(rawValue: sample.value)?.pregnancyTestValue ?? PregnancyTestEnum.inconclusive.value

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
