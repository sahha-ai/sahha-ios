import Testing
@testable import Sahha

@Suite("Biomarker categories")
struct BiomarkerCategoryTests {

    @Test("SahhaBiomarkerCategory matches the documented category list")
    func matchesDocumentedCategories() {
        // https://docs.sahha.ai/docs/products/biomarkers
        #expect(SahhaBiomarkerCategory.allCases.map(\.rawValue) == [
            "activity",
            "body",
            "engagement",
            "nutrition",
            "sleep",
            "vitals",
        ])
    }

    /// getStats/getSamples label every row with the sensor's upload logType
    /// (`sensor.dataLogType.stringValue`), matching the Android SDK. This pins the
    /// full sensor→label mapping: a change here changes public getStats/getSamples
    /// output AND the logType stamped on uploaded DataLogs (including dedup IDs).
    @Test("SahhaStat/SahhaSample category labels equal the upload logType per sensor")
    func sensorLabelsMatchUploadLogType() {
        let expected: [String: [SahhaSensor]] = [
            "sleep": [.sleep],
            "activity": [
                .activity_summary, .exercise_time, .floors_climbed, .move_time,
                .running_ground_contact_time, .running_power, .running_speed,
                .running_stride_length, .running_vertical_oscillation,
                .six_minute_walk_test_distance, .stair_ascent_speed, .stair_descent_speed,
                .stand_time, .steps, .walking_asymmetry_percentage,
                .walking_double_support_percentage, .walking_speed, .walking_steadiness,
                .walking_step_length,
            ],
            "heart": [
                .heart_rate, .heart_rate_variability_rmssd, .heart_rate_variability_sdnn,
                .resting_heart_rate, .walking_heart_rate_average,
            ],
            "blood": [.blood_glucose, .blood_pressure_diastolic, .blood_pressure_systolic],
            "oxygen": [.oxygen_saturation, .respiratory_rate, .vo2_max],
            "energy": [
                .active_energy_burned, .basal_energy_burned, .basal_metabolic_rate,
                .time_in_daylight, .total_energy_burned,
            ],
            "temperature": [.basal_body_temperature, .body_temperature, .sleeping_wrist_temperature],
            "body": [
                .body_fat, .body_mass_index, .body_water_mass, .bone_mass, .height,
                .lean_body_mass, .waist_circumference, .weight,
            ],
            "device": [.device_lock],
            "exercise": [.exercise],
            "demographic": [.date_of_birth, .gender],
            "nutrition": [
                .biotin_intake, .caffeine_intake, .calcium_intake, .carbohydrate_intake,
                .chloride_intake, .cholesterol_intake, .chromium_intake, .copper_intake,
                .energy_intake, .fat_intake, .fat_monounsaturated_intake,
                .fat_polyunsaturated_intake, .fat_saturated_intake, .fiber_intake,
                .folate_intake, .iodine_intake, .iron_intake, .magnesium_intake,
                .manganese_intake, .molybdenum_intake, .niacin_intake, .nutrition,
                .pantothenic_acid_intake, .phosphorus_intake, .potassium_intake,
                .protein_intake, .riboflavin_intake, .selenium_intake, .sodium_intake,
                .sugar_intake, .thiamin_intake, .vitamin_a_intake, .vitamin_b12_intake,
                .vitamin_b6_intake, .vitamin_c_intake, .vitamin_d_intake, .vitamin_e_intake,
                .vitamin_k_intake, .water_intake, .zinc_intake,
            ],
            "reproductive": [
                .cervical_mucus, .contraceptive, .infrequent_menstrual_cycles,
                .intermenstrual_bleeding, .irregular_menstrual_cycles, .lactation,
                .menstrual_flow, .menstrual_period, .ovulation_test,
                .persistent_intermenstrual_bleeding, .pregnancy, .pregnancy_test,
                .progesterone_test, .prolonged_menstrual_periods, .reproductive,
                .sexual_activity,
            ],
            "symptom": [
                .abdominal_cramps, .acne, .appetite_changes, .bladder_incontinence,
                .bloating, .breast_pain, .chest_tightness_or_pain, .chills, .constipation,
                .coughing, .diarrhea, .dizziness, .dry_skin, .fainting, .fatigue, .fever,
                .generalized_body_ache, .hair_loss, .headache, .heartburn, .hot_flashes,
                .loss_of_smell, .loss_of_taste, .lower_back_pain, .memory_lapse,
                .mood_changes, .nausea, .night_sweats, .pelvic_pain,
                .rapid_pounding_or_fluttering_heartbeat, .runny_nose, .shortness_of_breath,
                .sinus_congestion, .skipped_heartbeat, .sleep_changes, .sore_throat,
                .symptom, .vaginal_dryness, .vomiting, .wheezing,
            ],
        ]

        // The table is total: every sensor appears exactly once.
        let tabled = expected.values.flatMap { $0 }
        #expect(tabled.count == SahhaSensor.allCases.count)
        #expect(Set(tabled) == Set(SahhaSensor.allCases))

        for (label, sensors) in expected {
            for sensor in sensors {
                #expect(sensor.dataLogType.stringValue == label, "\(sensor.rawValue) should be labeled \(label)")
            }
        }

        // The former SensorCategory-only labels never appear in output.
        let emitted = Set(SahhaSensor.allCases.map(\.dataLogType.stringValue))
        #expect(!emitted.contains("vitals"))
        #expect(!emitted.contains("characteristic"))
    }
}
