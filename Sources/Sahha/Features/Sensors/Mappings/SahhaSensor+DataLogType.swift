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
        case .energy_consumed, .dietary_protein, .dietary_fat_total, .dietary_fat_saturated,
             .dietary_fat_monounsaturated, .dietary_fat_polyunsaturated, .dietary_cholesterol,
             .dietary_carbohydrates, .dietary_sugar, .dietary_fiber, .dietary_vitamin_a,
             .dietary_vitamin_d, .dietary_vitamin_e, .dietary_vitamin_k, .dietary_vitamin_c,
             .dietary_vitamin_b6, .dietary_vitamin_b12, .dietary_thiamin, .dietary_riboflavin,
             .dietary_niacin, .dietary_pantothenic_acid, .dietary_folate, .dietary_biotin,
             .dietary_calcium, .dietary_iron, .dietary_magnesium, .dietary_phosphorus,
             .dietary_potassium, .dietary_sodium, .dietary_zinc, .dietary_chloride,
             .dietary_copper, .dietary_manganese, .dietary_chromium, .dietary_molybdenum,
             .dietary_selenium, .dietary_iodine, .dietary_caffeine, .dietary_water:
            return .nutrition
            
        // MARK: - Reproductive Health (43 types)
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
            return .reproductive

        // MARK: - Umbrella
        case .nutrition:
            return .nutrition
        case .reproductive:
            return .reproductive
        }
    }
}
