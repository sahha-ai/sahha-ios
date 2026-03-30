import HealthKit

/// Normaliser for HKCategoryTypeIdentifier.pregnancyTestResult → Tag.
///
/// value maps to the platform-agnostic PregnancyTestEnum ordinal (aligned with Android):
///   0.0 = INCONCLUSIVE  (HK: indeterminate)
///   1.0 = NEGATIVE
///   2.0 = POSITIVE
final class HKPregnancyTestToTagNormaliser: HKSampleToTagNormaliserProtocol {
    func normalise(_ sample: HKSample) -> [Tag] {
        guard let sample = sample as? HKCategorySample,
            let sensor = sample.categoryType.sahhaSensor
        else { return [] }

        let value = HKCategoryValuePregnancyTestResult(rawValue: sample.value)?.pregnancyTestValue ?? PregnancyTestEnum.inconclusive.value

        return [
            Tag(
                type: .event,
                startDateTime: sample.startDate,
                name: sensor.rawValue,
                category: "reproductive",
                value: String(value),
                source: sample.sourceId
            )
        ]
    }
}
