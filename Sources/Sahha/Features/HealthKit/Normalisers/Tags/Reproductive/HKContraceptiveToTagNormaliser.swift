import HealthKit

/// Normaliser for HKCategoryTypeIdentifier.contraceptive → Tag.
///
/// Contraceptive method is modelled as a `.state` because the underlying domain
/// is "what method is in effect from when until when", not a point-in-time event.
/// This is consistent with how Flo, Garmin, Oura, Clue and other reproductive
/// trackers represent contraceptive method natively, and matches the existing
/// `.state` treatment of pregnancy and lactation.
///
/// Samples logged at a single instant in HealthKit will surface as zero-duration
/// state spans (`startDateTime == endDateTime`). An in-effect method that HealthKit
/// marks open-ended with `Date.distantFuture` is emitted with a nil endDateTime —
/// see [Date.isDistantFutureSentinel]. Per-pill / per-dose adherence signals — if
/// ever captured — would belong on a separate event-typed sensor.
///
/// value maps to the platform-agnostic ContraceptiveEnum snake_case string
/// (aligned with Android):
///   "unknown"            (HK: unspecified)
///   "implant"
///   "injection"
///   "intravaginal_ring"
///   "iud"
///   "oral"
///   "patch"
final class HKContraceptiveToTagNormaliser: HKSampleToTagNormaliserProtocol {
    func normalise(_ sample: HKSample, profileId: String?) -> [Tag] {
        guard let sample = sample as? HKCategorySample,
            let sensor = sample.categoryType.sahhaSensor
        else { return [] }

        let value = HKCategoryValueContraceptive(rawValue: sample.value)?.contraceptiveValue ?? ContraceptiveEnum.unknown.value
        let endDateTime: Date? = sample.endDate.isDistantFutureSentinel ? nil : sample.endDate

        return [
            Tag(
                profileId: profileId,
                type: .state,
                startDateTime: sample.startDate,
                endDateTime: endDateTime,
                name: sensor.rawValue,
                category: "reproductive",
                value: value,
                source: sample.sourceId
            )
        ]
    }
}
