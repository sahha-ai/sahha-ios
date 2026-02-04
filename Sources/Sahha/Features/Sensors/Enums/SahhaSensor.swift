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
    case dietary_protein
    case dietary_fat_total
    case dietary_fat_saturated
    case dietary_fat_monounsaturated
    case dietary_fat_polyunsaturated
    case dietary_cholesterol
    case dietary_carbohydrates
    case dietary_sugar
    case dietary_fiber
    case dietary_vitamin_a
    case dietary_vitamin_d
    case dietary_vitamin_e
    case dietary_vitamin_k
    case dietary_vitamin_c
    case dietary_vitamin_b6
    case dietary_vitamin_b12
    case dietary_thiamin
    case dietary_riboflavin
    case dietary_niacin
    case dietary_pantothenic_acid
    case dietary_folate
    case dietary_biotin
    case dietary_calcium
    case dietary_iron
    case dietary_magnesium
    case dietary_phosphorus
    case dietary_potassium
    case dietary_sodium
    case dietary_zinc
    case dietary_chloride
    case dietary_copper
    case dietary_manganese
    case dietary_chromium
    case dietary_molybdenum
    case dietary_selenium
    case dietary_iodine
    case dietary_caffeine
    case dietary_water
    
    // MARK: - Reproductive Health - Menstrual Cycle (6 types)
    case menstrual_flow
    case intermenstrual_bleeding
    case infrequent_menstrual_cycles
    case irregular_menstrual_cycles
    case persistent_intermenstrual_bleeding
    case prolonged_menstrual_periods
    
    // MARK: - Reproductive Health - Fertility (2 types)
    case ovulation_test_result
    case cervical_mucus_quality
    
    // MARK: - Reproductive Health - Sexual Activity (2 types)
    case sexual_activity
    case contraceptive
    
    // MARK: - Reproductive Health - Pregnancy (4 types)
    case pregnancy
    case pregnancy_test_result
    case progesterone_test_result
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
}
