import HealthKit

/// Normaliser for HKCategoryTypeIdentifier.cervicalMucusQuality → Tag.
///
/// value maps to the platform-agnostic CervicalMucusEnum snake_case string (aligned with Android):
///   "unknown"
///   "dry"
///   "sticky"
///   "creamy"
///   "watery"
///   "egg_white"
///
/// Note: Android defines "unusual" (Health Connect only — no HealthKit equivalent).
final class HKCervicalMucusToTagNormaliser: HKSampleToTagNormaliserProtocol {
    func normalise(_ sample: HKSample) -> [Tag] {
        guard let sample = sample as? HKCategorySample,
            let sensor = sample.categoryType.sahhaSensor
        else { return [] }

        let value = HKCategoryValueCervicalMucusQuality(rawValue: sample.value)?.cervicalMucusValue ?? CervicalMucusEnum.unknown.value

        return [
            Tag(
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
