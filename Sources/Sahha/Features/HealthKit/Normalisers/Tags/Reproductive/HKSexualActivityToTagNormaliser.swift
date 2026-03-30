import HealthKit

/// Normaliser for `sexualActivity` HKCategorySamples → Tag.
///
/// HealthKit stores sexual activity as a presence-only event (`sample.value`
/// is always `HKCategoryValue.notApplicable`). Whether protection was used is
/// carried in metadata under `HKMetadataKeySexualActivityProtectionUsed`.
///
/// Unified cross-platform value mapping (matches Android Health Connect):
///
/// | Metadata value | Unified value | Meaning     |
/// |----------------|---------------|-------------|
/// | `nil` / absent |     0.0       | UNKNOWN     |
/// | `true`         |     1.0       | PROTECTED   |
/// | `false`        |     2.0       | UNPROTECTED |
final class HKSexualActivityToTagNormaliser: HKSampleToTagNormaliserProtocol {
    func normalise(_ sample: HKSample) -> [Tag] {
        guard let sample = sample as? HKCategorySample,
              let sensor = sample.categoryType.sahhaSensor
        else { return [] }

        let protectionUsed = sample.metadata?[HKMetadataKeySexualActivityProtectionUsed] as? Bool
        let value: Double
        switch protectionUsed {
        case true:  value = SexualActivityEnum.protected_.value
        case false: value = SexualActivityEnum.unprotected.value
        default:    value = SexualActivityEnum.unknown.value
        }

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
