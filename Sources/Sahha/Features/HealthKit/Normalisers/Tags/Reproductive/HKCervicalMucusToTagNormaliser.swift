import HealthKit

/// Normaliser for HKCategoryTypeIdentifier.cervicalMucusQuality → Tag.
///
/// value maps to the platform-agnostic CervicalMucusEnum ordinal (aligned with Android):
///   0.0 = UNKNOWN
///   1.0 = DRY
///   2.0 = STICKY
///   3.0 = CREAMY
///   4.0 = WATERY
///   5.0 = EGG_WHITE
///
/// Note: Android defines 6.0 = UNUSUAL (Health Connect only — no HealthKit equivalent).
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
                value: String(value),
                source: sample.sourceId
            )
        ]
    }
}
