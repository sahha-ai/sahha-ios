import HealthKit

/// Normaliser for HKCategoryTypeIdentifier.ovulationTestResult → Tag.
///
/// value maps to the platform-agnostic OvulationTestEnum snake_case string (aligned with Android):
///   "inconclusive"  (HC: RESULT_INCONCLUSIVE / HK: indeterminate)
///   "negative"      (HC: RESULT_NEGATIVE     / HK: negative)
///   "high"          (HC: RESULT_HIGH         / HK: estrogenSurge)
///   "positive"      (HC: RESULT_POSITIVE     / HK: luteinizingHormoneSurge)
final class HKOvulationTestToTagNormaliser: HKSampleToTagNormaliserProtocol {
    func normalise(_ sample: HKSample, profileId: String?) -> [Tag] {
        guard let sample = sample as? HKCategorySample,
            let sensor = sample.categoryType.sahhaSensor
        else { return [] }

        let value = HKCategoryValueOvulationTestResult(rawValue: sample.value)?.ovulationTestValue ?? OvulationTestEnum.inconclusive.value

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
