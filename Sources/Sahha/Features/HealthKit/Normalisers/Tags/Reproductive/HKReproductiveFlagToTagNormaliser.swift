import HealthKit

/// Normaliser for binary reproductive health flag category types → Tag:
///   - intermenstrual_bleeding
///   - infrequent_menstrual_cycles
///   - irregular_menstrual_cycles
///   - persistent_intermenstrual_bleeding
///   - prolonged_menstrual_periods
///   - pregnancy
///   - lactation
///
/// These types use HKCategoryValue.notApplicable as their only value — the presence
/// of a sample records that the condition was observed during the sample's time window.
/// value is always "1.0" to indicate presence (consistent with Android's event-marker pattern).
///
/// pregnancy and lactation use `.state` type (preserving endDate for duration),
/// all others use `.event`.
final class HKReproductiveFlagToTagNormaliser: HKSampleToTagNormaliserProtocol {

    private static let STATE_SENSORS: Set<SahhaSensor> = [
        .pregnancy,
        .lactation,
    ]

    func normalise(_ sample: HKSample) -> [Tag] {
        guard let sample = sample as? HKCategorySample,
            let sensor = sample.categoryType.sahhaSensor
        else { return [] }

        let isState = Self.STATE_SENSORS.contains(sensor)

        return [
            Tag(
                type: isState ? .state : .event,
                startDateTime: sample.startDate,
                endDateTime: isState ? sample.endDate : nil,
                name: sensor.rawValue,
                category: "reproductive",
                value: String(1.0),
                source: sample.sourceId
            )
        ]
    }
}
