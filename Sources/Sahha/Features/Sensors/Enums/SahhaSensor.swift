public enum SahhaSensor: String, CaseIterable, Codable, Sendable {
    // MARK: - Activity
    case activity_summary
    case active_energy_burned
    case exercise
    case exercise_time
    case floors_climbed
    case move_time
    case running_ground_contact_time
    case running_power
    case running_speed
    case running_stride_length
    case running_vertical_oscillation
    case six_minute_walk_test_distance
    case stair_ascent_speed
    case stair_descent_speed
    case stand_time
    case steps
    case time_in_daylight
    case walking_asymmetry_percentage
    case walking_double_support_percentage
    case walking_speed
    case walking_steadiness
    case walking_step_length
    
    // MARK: - Blood
    case blood_glucose
    case blood_pressure_diastolic
    case blood_pressure_systolic
    
    // MARK: - Body
    case body_fat
    case body_mass_index
    case body_water_mass
    case bone_mass
    case height
    case lean_body_mass
    case waist_circumference
    case weight
    
    // MARK: - Demographic
    case date_of_birth
    case gender
    
    // MARK: - Device
    case device_lock
    
    // MARK: - Energy
    case basal_energy_burned
    case basal_metabolic_rate
    case total_energy_burned
    
    // MARK: - Heart
    case heart_rate
    case heart_rate_variability_rmssd
    case heart_rate_variability_sdnn
    case resting_heart_rate
    case walking_heart_rate_average
    
    // MARK: - Oxygen
    case oxygen_saturation
    case respiratory_rate
    case vo2_max
    
    // MARK: - Sleep
    case sleep
    
    // MARK: - Temperature
    case basal_body_temperature
    case body_temperature
    case sleeping_wrist_temperature
    
    // MARK: - Nutrition (38 types)
    case energy_consumed
    case protein_intake
    case fat_intake
    case fat_saturated_intake
    case fat_monounsaturated_intake
    case fat_polyunsaturated_intake
    case cholesterol_intake
    case carbohydrate_intake
    case sugar_intake
    case fiber_intake
    case vitamin_a_intake
    case vitamin_d_intake
    case vitamin_e_intake
    case vitamin_k_intake
    case vitamin_c_intake
    case vitamin_b6_intake
    case vitamin_b12_intake
    case vitamin_b1_intake
    case vitamin_b2_intake
    case vitamin_b3_intake
    case vitamin_b5_intake
    case viatmin_b9_intake
    case vitamin_b7_intake
    case calcium_intake
    case iron_intake
    case magnesium_intake
    case phosphorus_intake
    case potassium_intake
    case sodium_intake
    case zinc_intake
    case chloride_intake
    case copper_intake
    case manganese_intake
    case chromium_intake
    case molybdenum_intake
    case selenium_intake
    case iodine_intake
    case caffeine_intake
    case water_intake
    
    // MARK: - Reproductive Health - Menstrual Cycle (6 types)
    case menstrual_flow
    case intermenstrual_bleeding
    case infrequent_menstrual_cycles
    case irregular_menstrual_cycles
    case persistent_intermenstrual_bleeding
    case prolonged_menstrual_periods
    
    // MARK: - Reproductive Health - Fertility (2 types)
    case ovulation_test
    case cervical_mucus
    
    // MARK: - Reproductive Health - Sexual Activity (2 types)
    case sexual_activity
    case contraceptive
    
    // MARK: - Reproductive Health - Pregnancy (4 types)
    case pregnancy
    case pregnancy_test
    case progesterone_test
    case lactation
    
    // MARK: - Reproductive Health - Symptoms (29 types)
    case abdominal_cramps
    case acne
    case appetite_changes
    case bladder_incontinence
    case bloating
    case breast_pain
    case chills
    case constipation
    case diarrhea
    case dizziness
    case dry_skin
    case fatigue
    case hair_loss
    case headache
    case hot_flashes
    case lower_back_pain
    case memory_lapse
    case mood_changes
    case nausea
    case night_sweats
    case pelvic_pain
    case rapid_pounding_or_fluttering_heartbeat
    case runny_nose
    case sinus_congestion
    case skipped_heartbeat
    case sleep_changes
    case sore_throat
    case vaginal_dryness
    case vomiting

    // MARK: - Umbrella (blanket terms for permissions; expand to granular sensors internally)
    case nutrition   // All dietary/nutrition HealthKit types
    case reproductive // All reproductive health HealthKit types
}

extension SahhaSensor {
    /// Replaces umbrella sensors (.nutrition, .reproductive) with all underlying granular sensors.
    /// Use at API entry points so the app can pass [.nutrition] instead of 38+ individual types.
    static func expanded(_ sensors: Set<SahhaSensor>) -> Set<SahhaSensor> {
        var result = sensors
        if result.remove(.nutrition) != nil {
            result.formUnion(SahhaSensor.allCases.filter { $0 != .nutrition && $0.category == .nutrition })
        }
        if result.remove(.reproductive) != nil {
            result.formUnion(SahhaSensor.allCases.filter { $0 != .reproductive && $0.category == .reproductive })
        }
        return result
    }
}
