import HealthKit

/// Normaliser for all 29 reproductive health symptom category types → Tag.
///
/// value is the raw HKCategoryValueSeverity ordinal — symptoms carry meaningful severity:
///   0 = unspecified
///   1 = notPresent
///   2 = mild
///   3 = moderate
///   4 = severe
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

        return [
            Tag(
                type: .event,
                startDateTime: sample.startDate,
                name: sensor.rawValue,
                category: "reproductive",
                value: String(Double(sample.value)),
                source: sample.sourceId
            )
        ]
    }
}
