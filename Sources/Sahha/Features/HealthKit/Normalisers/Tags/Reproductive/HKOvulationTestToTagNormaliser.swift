import HealthKit

/// Normaliser for HKCategoryTypeIdentifier.ovulationTestResult → Tag.
///
/// value maps to the platform-agnostic OvulationTestEnum ordinal (aligned with Android):
///   0.0 = INCONCLUSIVE  (HC: RESULT_INCONCLUSIVE / HK: indeterminate)
///   1.0 = NEGATIVE      (HC: RESULT_NEGATIVE     / HK: negative)
///   2.0 = HIGH          (HC: RESULT_HIGH         / HK: estrogenSurge)
///   3.0 = POSITIVE      (HC: RESULT_POSITIVE     / HK: luteinizingHormoneSurge)
final class HKOvulationTestToTagNormaliser: HKSampleToTagNormaliserProtocol {
    func normalise(_ sample: HKSample) -> [Tag] {
        guard let sample = sample as? HKCategorySample,
            let sensor = sample.categoryType.sahhaSensor
        else { return [] }

        let value = HKCategoryValueOvulationTestResult(rawValue: sample.value)?.ovulationTestValue ?? OvulationTestEnum.inconclusive.value

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
