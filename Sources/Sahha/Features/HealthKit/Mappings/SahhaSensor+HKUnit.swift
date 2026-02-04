import HealthKit

extension SahhaSensor {
    var hkUnit: HKUnit? {
        switch self {

        // MARK: - Demographic
        case .gender, .date_of_birth:
            return nil

        // MARK: - Sleep
        case .sleep:
            return .count()

        // MARK: - Activity
        case .steps, .floors_climbed:
            return .count()
        case .move_time, .stand_time, .exercise_time, .time_in_daylight:
            return .minute()
        case .activity_summary:
            return nil
        case .walking_asymmetry_percentage, .walking_double_support_percentage, .walking_steadiness:
            return .percent()
        case .walking_step_length, .running_stride_length, .six_minute_walk_test_distance:
            return .meter()
        case .walking_speed, .running_speed, .stair_ascent_speed, .stair_descent_speed:
            return .meter().unitDivided(by: .second())
        case .running_power:
            guard #available(iOS 16.0, *) else { return nil }
            return .watt()
        case .running_ground_contact_time:
            return .secondUnit(with: .milli)
        case .running_vertical_oscillation:
            return .meterUnit(with: .centi)
        case .exercise:
            return nil

        // MARK: - Heart
        case .heart_rate, .resting_heart_rate, .walking_heart_rate_average:
            return .count().unitDivided(by: .minute())
        case .heart_rate_variability_sdnn:
            return .secondUnit(with: .milli)
        case .heart_rate_variability_rmssd:
            return nil

        // MARK: - Blood
        case .blood_pressure_systolic, .blood_pressure_diastolic:
            return .millimeterOfMercury()
        case .blood_glucose:
            return HKUnit(from: "mg/dL")

        // MARK: - Oxygen
        case .oxygen_saturation:
            return .percent()
        case .vo2_max:
            return HKUnit(from: "ml/kg*min")
        case .respiratory_rate:
            return .count().unitDivided(by: .second())

        // MARK: - Energy
        case .active_energy_burned, .basal_energy_burned, .energy_consumed:
            return .largeCalorie()
        case .basal_metabolic_rate, .total_energy_burned:
            return nil

        // MARK: - Temperature
        case .body_temperature, .basal_body_temperature, .sleeping_wrist_temperature:
            return .degreeCelsius()

        // MARK: - Body
        case .height, .waist_circumference:
            return .meter()
        case .weight, .lean_body_mass:
            return .gramUnit(with: .kilo)
        case .body_mass_index:
            return .count()
        case .body_fat:
            return .percent()
        case .body_water_mass, .bone_mass:
            return nil

        // MARK: - Device
        case .device_lock:
            return nil
            
        // MARK: - Nutrition - Macronutrients (grams)
        case .dietary_protein, .dietary_fat_total, .dietary_fat_saturated,
             .dietary_fat_monounsaturated, .dietary_fat_polyunsaturated,
             .dietary_carbohydrates, .dietary_sugar, .dietary_fiber:
            return .gram()
            
        // MARK: - Nutrition - Cholesterol (milligrams)
        case .dietary_cholesterol:
            return .gramUnit(with: .milli)
            
        // MARK: - Nutrition - Vitamins (mixed units)
        case .dietary_vitamin_a, .dietary_vitamin_d, .dietary_vitamin_k,
             .dietary_vitamin_b12, .dietary_folate, .dietary_biotin:
            return .gramUnit(with: .micro) // micrograms
        case .dietary_vitamin_e, .dietary_vitamin_c, .dietary_vitamin_b6,
             .dietary_thiamin, .dietary_riboflavin, .dietary_niacin,
             .dietary_pantothenic_acid:
            return .gramUnit(with: .milli) // milligrams
            
        // MARK: - Nutrition - Minerals (mostly milligrams)
        case .dietary_calcium, .dietary_iron, .dietary_magnesium,
             .dietary_phosphorus, .dietary_potassium, .dietary_sodium,
             .dietary_zinc, .dietary_chloride, .dietary_copper,
             .dietary_manganese, .dietary_caffeine:
            return .gramUnit(with: .milli)
        case .dietary_chromium, .dietary_molybdenum, .dietary_selenium, .dietary_iodine:
            return .gramUnit(with: .micro) // micrograms
            
        // MARK: - Nutrition - Water (liters)
        case .dietary_water:
            return .liter()
            
        // MARK: - Reproductive Health (Category types - no units)
        case .menstrual_flow, .intermenstrual_bleeding, .infrequent_menstrual_cycles,
             .irregular_menstrual_cycles, .persistent_intermenstrual_bleeding,
             .prolonged_menstrual_periods, .ovulation_test_result, .cervical_mucus_quality,
             .sexual_activity, .contraceptive, .pregnancy, .pregnancy_test_result,
             .progesterone_test_result, .lactation, .abdominal_cramps, .acne,
             .appetite_changes, .bladder_incontinence, .bloating, .breast_pain,
             .chills, .constipation, .diarrhea, .dizziness, .dry_skin, .fatigue,
             .hair_loss, .headache, .hot_flashes, .lower_back_pain, .memory_lapse,
             .mood_changes, .nausea, .night_sweats, .pelvic_pain,
             .rapid_pounding_or_fluttering_heartbeat, .runny_nose, .sinus_congestion,
             .skipped_heartbeat, .sleep_changes, .sore_throat, .vaginal_dryness, .vomiting:
            return nil // Category types don't have units
        }
    }
}
