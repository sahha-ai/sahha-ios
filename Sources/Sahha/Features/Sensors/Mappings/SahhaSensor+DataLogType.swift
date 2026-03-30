extension SahhaSensor {
    var dataLogType: DataLogType {
        switch self {
        case .gender, .date_of_birth:
            return .demographic
        case .sleep:
            return .sleep
        case .steps, .floors_climbed, .move_time, .stand_time, .exercise_time, .activity_summary,
            .walking_asymmetry_percentage, .walking_speed, .walking_steadiness,
            .walking_double_support_percentage, .walking_step_length, .running_speed, .running_power,
            .running_ground_contact_time, .running_stride_length, .running_vertical_oscillation,
            .six_minute_walk_test_distance, .stair_ascent_speed, .stair_descent_speed:
            return .activity
        case .heart_rate, .resting_heart_rate, .walking_heart_rate_average, .heart_rate_variability_sdnn, .heart_rate_variability_rmssd:
            return .heart
        case .blood_pressure_systolic, .blood_pressure_diastolic, .blood_glucose:
            return .blood
        case .oxygen_saturation, .vo2_max, .respiratory_rate:
            return .oxygen
        case .active_energy_burned, .basal_energy_burned, .total_energy_burned, .basal_metabolic_rate, .time_in_daylight:
            return .energy
        case .body_temperature, .basal_body_temperature, .sleeping_wrist_temperature:
            return .temperature
        case .height, .weight, .lean_body_mass, .body_mass_index, .body_fat, .waist_circumference, .body_water_mass, .bone_mass:
            return .body
        case .device_lock:
            return .device
        case .exercise:
            return .exercise
            
        // MARK: - Nutrition (38 types)
        case .energy_consumed, .protein_intake, .fat_intake, .fat_saturated_intake,
             .fat_monounsaturated_intake, .fat_polyunsaturated_intake, .cholesterol_intake,
             .carbohydrate_intake, .sugar_intake, .fiber_intake, .vitamin_a_intake,
             .vitamin_d_intake, .vitamin_e_intake, .vitamin_k_intake, .vitamin_c_intake,
             .vitamin_b6_intake, .vitamin_b12_intake, .vitamin_b1_intake, .vitamin_b2_intake,
             .vitamin_b3_intake, .vitamin_b5_intake, .viatmin_b9_intake, .vitamin_b7_intake,
             .calcium_intake, .iron_intake, .magnesium_intake, .phosphorus_intake,
             .potassium_intake, .sodium_intake, .zinc_intake, .chloride_intake,
             .copper_intake, .manganese_intake, .chromium_intake, .molybdenum_intake,
             .selenium_intake, .iodine_intake, .caffeine_intake, .water_intake:
            return .nutrition
            
        // MARK: - Reproductive Health (14 types)
        case .menstrual_flow, .intermenstrual_bleeding, .infrequent_menstrual_cycles,
             .irregular_menstrual_cycles, .persistent_intermenstrual_bleeding,
             .prolonged_menstrual_periods, .ovulation_test, .cervical_mucus,
             .sexual_activity, .contraceptive, .pregnancy, .pregnancy_test,
             .progesterone_test, .lactation:
            return .reproductive

        // MARK: - Symptoms (29 types)
        case .abdominal_cramps, .acne, .appetite_changes, .bladder_incontinence,
             .bloating, .breast_pain, .chills, .constipation, .diarrhea, .dizziness,
             .dry_skin, .fatigue, .hair_loss, .headache, .hot_flashes, .lower_back_pain,
             .memory_lapse, .mood_changes, .nausea, .night_sweats, .pelvic_pain,
             .rapid_pounding_or_fluttering_heartbeat, .runny_nose, .sinus_congestion,
             .skipped_heartbeat, .sleep_changes, .sore_throat, .vaginal_dryness, .vomiting:
            return .symptom

        // MARK: - Umbrella
        case .nutrition:
            return .nutrition
        case .reproductive:
            return .reproductive
        case .symptom:
            return .symptom
        }
    }
}
