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
/// value is nil since the tag's presence alone is sufficient.
///
/// pregnancy and lactation use `.state` type (preserving endDate for duration),
/// all others use `.event`. Ongoing states that HealthKit marks open-ended with
/// `Date.distantFuture` are emitted with a nil endDateTime — see [Date.isDistantFutureSentinel].
final class HKReproductiveFlagToTagNormaliser: HKSampleToTagNormaliserProtocol {

    private static let STATE_SENSORS: Set<SahhaSensor> = [
        .pregnancy,
        .lactation,
    ]

    func normalise(_ sample: HKSample, profileId: String?) -> [Tag] {
        guard let sample = sample as? HKCategorySample,
            let sensor = sample.categoryType.sahhaSensor
        else { return [] }

        let isState = Self.STATE_SENSORS.contains(sensor)
        let endDateTime: Date? = isState && !sample.endDate.isDistantFutureSentinel ? sample.endDate : nil

        return [
            Tag(
                profileId: profileId,
                type: isState ? .state : .event,
                startDateTime: sample.startDate,
                endDateTime: endDateTime,
                name: sensor.rawValue,
                category: "reproductive",
                value: nil,
                source: sample.sourceId
            )
        ]
    }
}
