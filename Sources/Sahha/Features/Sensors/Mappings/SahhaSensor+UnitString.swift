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
        case .dietary_protein, .dietary_fat_total, .dietary_fat_saturated,
             .dietary_fat_monounsaturated, .dietary_fat_polyunsaturated,
             .dietary_carbohydrates, .dietary_sugar, .dietary_fiber:
            "g"
            
        // MARK: - Nutrition - Milligrams
        case .dietary_cholesterol, .dietary_vitamin_e, .dietary_vitamin_c,
             .dietary_vitamin_b6, .dietary_thiamin, .dietary_riboflavin,
             .dietary_niacin, .dietary_pantothenic_acid, .dietary_calcium,
             .dietary_iron, .dietary_magnesium, .dietary_phosphorus,
             .dietary_potassium, .dietary_sodium, .dietary_zinc, .dietary_chloride,
             .dietary_copper, .dietary_manganese, .dietary_caffeine:
            "mg"
            
        // MARK: - Nutrition - Micrograms
        case .dietary_vitamin_a, .dietary_vitamin_d, .dietary_vitamin_k,
             .dietary_vitamin_b12, .dietary_folate, .dietary_biotin,
             .dietary_chromium, .dietary_molybdenum, .dietary_selenium, .dietary_iodine:
            "mcg"
            
        // MARK: - Nutrition - Liters
        case .dietary_water:
            "L"
            
        // MARK: - Reproductive Health (Category values - no units, value is enum index)
        case .menstrual_flow, .intermenstrual_bleeding, .infrequent_menstrual_cycles,
             .irregular_menstrual_cycles, .persistent_intermenstrual_bleeding,
             .prolonged_menstrual_periods, .ovulation_test_result, .cervical_mucus_quality,
             .sexual_activity, .contraceptive, .pregnancy, .pregnancy_test_result,
             .progesterone_test_result, .lactation, .abdominal_cramps, .acne,
             .appetite_changes, .bladder_incontinence, .bloating, .breast_pain, .chills,
             .constipation, .diarrhea, .dizziness, .dry_skin, .fatigue, .hair_loss,
             .headache, .hot_flashes, .lower_back_pain, .memory_lapse, .mood_changes,
             .nausea, .night_sweats, .pelvic_pain, .rapid_pounding_or_fluttering_heartbeat,
             .runny_nose, .sinus_congestion, .skipped_heartbeat, .sleep_changes,
             .sore_throat, .vaginal_dryness, .vomiting:
            "category"

        // MARK: - Umbrella (not used for samples; expanded before query)
        case .nutrition, .reproductive:
            ""
        }
    }
}
