extension SahhaSensor {
    var unitString: String {
        return switch self {
        case .heart_rate, .resting_heart_rate, .walking_heart_rate_average:
            "bpm"
        case .heart_rate_variability_sdnn, .running_ground_contact_time:
            "ms"
        case .vo2_max:
            "ml/kg/min"
        case .oxygen_saturation, .body_fat, .walking_steadiness, .walking_asymmetry_percentage, .walking_double_support_percentage:
            "percent"
        case .respiratory_rate:
            "bps"
        case .active_energy_burned, .basal_energy_burned, .energy_consumed:
            "kcal"
        case .sleep, .time_in_daylight, .stand_time, .move_time, .exercise_time, .exercise:
            "minute"
        case .body_temperature, .basal_body_temperature, .sleeping_wrist_temperature:
            "degC"
        case .height, .waist_circumference, .running_stride_length, .six_minute_walk_test_distance, .walking_step_length:
            "m"
        case .running_vertical_oscillation:
            "cm"
        case .stair_ascent_speed, .stair_descent_speed, .walking_speed, .running_speed:
            "m/s"
        case .running_power:
            "watt"
        case .weight, .lean_body_mass:
            "kg"
        case .blood_pressure_systolic, .blood_pressure_diastolic:
            "mmHg"
        case .blood_glucose:
            "mg/dL"
        case .steps, .floors_climbed, .body_mass_index, .activity_summary:
            "count"
        case .gender, .date_of_birth, .device_lock, .heart_rate_variability_rmssd,
            .total_energy_burned, .basal_metabolic_rate, .body_water_mass, .bone_mass:
            ""
            
        // MARK: - Nutrition - Grams
        case .protein_intake, .fat_intake, .fat_saturated_intake,
             .fat_monounsaturated_intake, .fat_polyunsaturated_intake,
             .carbohydrate_intake, .sugar_intake, .fiber_intake:
            "g"
            
        // MARK: - Nutrition - Milligrams
        case .cholesterol_intake, .vitamin_e_intake, .vitamin_c_intake,
             .vitamin_b6_intake, .vitamin_b1_intake, .vitamin_b2_intake,
             .vitamin_b3_intake, .vitamin_b5_intake, .calcium_intake,
             .iron_intake, .magnesium_intake, .phosphorus_intake,
             .potassium_intake, .sodium_intake, .zinc_intake, .chloride_intake,
             .copper_intake, .manganese_intake, .caffeine_intake:
            "mg"
            
        // MARK: - Nutrition - Micrograms
        case .vitamin_a_intake, .vitamin_d_intake, .vitamin_k_intake,
             .vitamin_b12_intake, .vitamin_b9_intake, .vitamin_b7_intake,
             .chromium_intake, .molybdenum_intake, .selenium_intake, .iodine_intake:
            "mcg"
            
        // MARK: - Hydration - Liters
        case .water_intake:
            "L"
            
        // MARK: - Reproductive Health
        case .menstrual_flow, .intermenstrual_bleeding, .infrequent_menstrual_cycles,
             .irregular_menstrual_cycles, .persistent_intermenstrual_bleeding,
             .prolonged_menstrual_periods, .ovulation_test, .cervical_mucus,
             .sexual_activity, .contraceptive, .pregnancy, .pregnancy_test,
             .progesterone_test, .lactation, .abdominal_cramps, .acne,
             .appetite_changes, .bladder_incontinence, .bloating, .breast_pain, .chills,
             .constipation, .diarrhea, .dizziness, .dry_skin, .fatigue, .hair_loss,
             .headache, .hot_flashes, .lower_back_pain, .memory_lapse, .mood_changes,
             .nausea, .night_sweats, .pelvic_pain, .rapid_pounding_or_fluttering_heartbeat,
             .runny_nose, .sinus_congestion, .skipped_heartbeat, .sleep_changes,
             .sore_throat, .vaginal_dryness, .vomiting:
            ""

        // MARK: - Umbrella (not used for samples; expanded before query)
        case .nutrition, .reproductive, .symptom:
            ""
        }
    }
}
