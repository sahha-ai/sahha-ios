import HealthKit

/// Normaliser for all 29 health symptom category types → Tag.
///
/// value is the HKCategoryValueSeverity mapped to a snake_case string:
///   "unspecified"
///   "not_present"
///   "mild"
///   "moderate"
///   "severe"
///
/// Covered sensors:
///   abdominal_cramps, acne, appetite_changes, bladder_incontinence, bloating,
///   breast_pain, chills, constipation, diarrhea, dizziness, dry_skin, fatigue,
///   hair_loss, headache, hot_flashes, lower_back_pain, memory_lapse, mood_changes,
///   nausea, night_sweats, pelvic_pain, rapid_pounding_or_fluttering_heartbeat,
///   runny_nose, sinus_congestion, skipped_heartbeat, sleep_changes, sore_throat,
///   vaginal_dryness, vomiting
final class HKReproductiveSymptomToTagNormaliser: HKSampleToTagNormaliserProtocol {

    private static let SYMPTOM_SENSORS: Set<SahhaSensor> = [
        .abdominal_cramps,
        .acne,
        .appetite_changes,
        .bladder_incontinence,
        .bloating,
        .breast_pain,
        .chills,
        .constipation,
        .diarrhea,
        .dizziness,
        .dry_skin,
        .fatigue,
        .hair_loss,
        .headache,
        .hot_flashes,
        .lower_back_pain,
        .memory_lapse,
        .mood_changes,
        .nausea,
        .night_sweats,
        .pelvic_pain,
        .rapid_pounding_or_fluttering_heartbeat,
        .runny_nose,
        .sinus_congestion,
        .skipped_heartbeat,
        .sleep_changes,
        .sore_throat,
        .vaginal_dryness,
        .vomiting,
    ]

    func normalise(_ sample: HKSample) -> [Tag] {
        guard let sample = sample as? HKCategorySample,
              let sensor = sample.categoryType.sahhaSensor,
              Self.SYMPTOM_SENSORS.contains(sensor)
        else { return [] }

        let severity = HKCategoryValueSeverity(rawValue: sample.value)
        let value = severity?.severityValue ?? SeverityEnum.unknown.value
        let name = severity == .notPresent ? "no_\(sensor.rawValue)" : sensor.rawValue

        return [
            Tag(
                type: .event,
                startDateTime: sample.startDate,
                name: name,
                category: "symptom",
                value: value,
                source: sample.sourceId
            )
        ]
    }
}
