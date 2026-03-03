import HealthKit

extension SahhaSensor {
    var hkObjectType: HKObjectType? {
        switch self {
        
        // MARK: - Demographic
        case .gender:
            return HKCharacteristicType.characteristicType(forIdentifier: .biologicalSex)
        case .date_of_birth:
            return HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth)
        
        // MARK: - Sleep
        case .sleep:
            return HKSampleType.categoryType(forIdentifier: .sleepAnalysis)
        
        // MARK: - Activity
        case .steps:
            return HKQuantityType.quantityType(forIdentifier: .stepCount)
        case .floors_climbed:
            return HKQuantityType.quantityType(forIdentifier: .flightsClimbed)
        case .move_time:
            return HKQuantityType.quantityType(forIdentifier: .appleMoveTime)
        case .stand_time:
            return HKQuantityType.quantityType(forIdentifier: .appleStandTime)
        case .exercise_time:
            return HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)
        case .activity_summary:
            return HKSampleType.activitySummaryType()
        case .walking_asymmetry_percentage:
            return HKQuantityType.quantityType(forIdentifier: .walkingAsymmetryPercentage)
        case .walking_speed:
            return HKQuantityType.quantityType(forIdentifier: .walkingSpeed)
        case .walking_steadiness:
            return HKQuantityType.quantityType(forIdentifier: .appleWalkingSteadiness)
        case .walking_double_support_percentage:
            return HKQuantityType.quantityType(forIdentifier: .walkingDoubleSupportPercentage)
        case .walking_step_length:
            return HKQuantityType.quantityType(forIdentifier: .walkingStepLength)
        case .running_speed:
            if #available(iOS 16.0, *) {
                return HKQuantityType.quantityType(forIdentifier: .runningSpeed)
            } else { return nil }
        case .running_power:
            if #available(iOS 16.0, *) {
                return HKQuantityType.quantityType(forIdentifier: .runningPower)
            } else { return nil }
        case .running_ground_contact_time:
            if #available(iOS 16.0, *) {
                return HKQuantityType.quantityType(forIdentifier: .runningGroundContactTime)
            } else { return nil }
        case .running_stride_length:
            if #available(iOS 16.0, *) {
                return HKQuantityType.quantityType(forIdentifier: .runningStrideLength)
            } else { return nil }
        case .running_vertical_oscillation:
            if #available(iOS 16.0, *) {
                return HKQuantityType.quantityType(forIdentifier: .runningVerticalOscillation)
            } else { return nil }
        case .six_minute_walk_test_distance:
            return HKQuantityType.quantityType(forIdentifier: .sixMinuteWalkTestDistance)
        case .stair_ascent_speed:
            return HKQuantityType.quantityType(forIdentifier: .stairAscentSpeed)
        case .stair_descent_speed:
            return HKQuantityType.quantityType(forIdentifier: .stairDescentSpeed)
        case .exercise:
            return HKWorkoutType.workoutType()
        
        // MARK: - Heart
        case .heart_rate:
            return HKQuantityType.quantityType(forIdentifier: .heartRate)
        case .resting_heart_rate:
            return HKQuantityType.quantityType(forIdentifier: .restingHeartRate)
        case .walking_heart_rate_average:
            return HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage)
        case .heart_rate_variability_sdnn:
            return HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
        case .heart_rate_variability_rmssd:
            return nil
        
        // MARK: - Blood
        case .blood_pressure_systolic:
            return HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)
        case .blood_pressure_diastolic:
            return HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)
        case .blood_glucose:
            return HKQuantityType.quantityType(forIdentifier: .bloodGlucose)
        
        // MARK: - Oxygen
        case .oxygen_saturation:
            return HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)
        case .vo2_max:
            return HKQuantityType.quantityType(forIdentifier: .vo2Max)
        case .respiratory_rate:
            return HKQuantityType.quantityType(forIdentifier: .respiratoryRate)
        
        // MARK: - Energy
        case .active_energy_burned:
            return HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        case .basal_energy_burned:
            return HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)
        case .total_energy_burned:
            return nil
        case .basal_metabolic_rate:
            return nil
        case .time_in_daylight:
            if #available(iOS 17.0, *) {
                return HKQuantityType.quantityType(forIdentifier: .timeInDaylight)
            } else { return nil }
        
        // MARK: - Temperature
        case .body_temperature:
            return HKQuantityType.quantityType(forIdentifier: .bodyTemperature)
        case .basal_body_temperature:
            return HKQuantityType.quantityType(forIdentifier: .basalBodyTemperature)
        case .sleeping_wrist_temperature:
            if #available(iOS 16.0, *) {
                return HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature)
            } else { return nil }
        
        // MARK: - Body
        case .height:
            return HKQuantityType.quantityType(forIdentifier: .height)
        case .weight:
            return HKQuantityType.quantityType(forIdentifier: .bodyMass)
        case .lean_body_mass:
            return HKQuantityType.quantityType(forIdentifier: .leanBodyMass)
        case .body_mass_index:
            return HKQuantityType.quantityType(forIdentifier: .bodyMassIndex)
        case .body_fat:
            return HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)
        case .waist_circumference:
            return HKQuantityType.quantityType(forIdentifier: .waistCircumference)
        case .body_water_mass:
            return nil
        case .bone_mass:
            return nil
        
        // MARK: - Device
        case .device_lock:
            return nil
            
        // MARK: - Nutrition
        case .energy_consumed:
            return HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)
        case .dietary_protein:
            return HKQuantityType.quantityType(forIdentifier: .dietaryProtein)
        case .dietary_fat_total:
            return HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal)
        case .dietary_fat_saturated:
            return HKQuantityType.quantityType(forIdentifier: .dietaryFatSaturated)
        case .dietary_fat_monounsaturated:
            return HKQuantityType.quantityType(forIdentifier: .dietaryFatMonounsaturated)
        case .dietary_fat_polyunsaturated:
            return HKQuantityType.quantityType(forIdentifier: .dietaryFatPolyunsaturated)
        case .dietary_cholesterol:
            return HKQuantityType.quantityType(forIdentifier: .dietaryCholesterol)
        case .dietary_carbohydrates:
            return HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates)
        case .dietary_sugar:
            return HKQuantityType.quantityType(forIdentifier: .dietarySugar)
        case .dietary_fiber:
            return HKQuantityType.quantityType(forIdentifier: .dietaryFiber)
        case .dietary_vitamin_a:
            return HKQuantityType.quantityType(forIdentifier: .dietaryVitaminA)
        case .dietary_vitamin_d:
            return HKQuantityType.quantityType(forIdentifier: .dietaryVitaminD)
        case .dietary_vitamin_e:
            return HKQuantityType.quantityType(forIdentifier: .dietaryVitaminE)
        case .dietary_vitamin_k:
            return HKQuantityType.quantityType(forIdentifier: .dietaryVitaminK)
        case .dietary_vitamin_c:
            return HKQuantityType.quantityType(forIdentifier: .dietaryVitaminC)
        case .dietary_vitamin_b6:
            return HKQuantityType.quantityType(forIdentifier: .dietaryVitaminB6)
        case .dietary_vitamin_b12:
            return HKQuantityType.quantityType(forIdentifier: .dietaryVitaminB12)
        case .dietary_thiamin:
            return HKQuantityType.quantityType(forIdentifier: .dietaryThiamin)
        case .dietary_riboflavin:
            return HKQuantityType.quantityType(forIdentifier: .dietaryRiboflavin)
        case .dietary_niacin:
            return HKQuantityType.quantityType(forIdentifier: .dietaryNiacin)
        case .dietary_pantothenic_acid:
            return HKQuantityType.quantityType(forIdentifier: .dietaryPantothenicAcid)
        case .dietary_folate:
            return HKQuantityType.quantityType(forIdentifier: .dietaryFolate)
        case .dietary_biotin:
            return HKQuantityType.quantityType(forIdentifier: .dietaryBiotin)
        case .dietary_calcium:
            return HKQuantityType.quantityType(forIdentifier: .dietaryCalcium)
        case .dietary_iron:
            return HKQuantityType.quantityType(forIdentifier: .dietaryIron)
        case .dietary_magnesium:
            return HKQuantityType.quantityType(forIdentifier: .dietaryMagnesium)
        case .dietary_phosphorus:
            return HKQuantityType.quantityType(forIdentifier: .dietaryPhosphorus)
        case .dietary_potassium:
            return HKQuantityType.quantityType(forIdentifier: .dietaryPotassium)
        case .dietary_sodium:
            return HKQuantityType.quantityType(forIdentifier: .dietarySodium)
        case .dietary_zinc:
            return HKQuantityType.quantityType(forIdentifier: .dietaryZinc)
        case .dietary_chloride:
            return HKQuantityType.quantityType(forIdentifier: .dietaryChloride)
        case .dietary_copper:
            return HKQuantityType.quantityType(forIdentifier: .dietaryCopper)
        case .dietary_manganese:
            return HKQuantityType.quantityType(forIdentifier: .dietaryManganese)
        case .dietary_chromium:
            return HKQuantityType.quantityType(forIdentifier: .dietaryChromium)
        case .dietary_molybdenum:
            return HKQuantityType.quantityType(forIdentifier: .dietaryMolybdenum)
        case .dietary_selenium:
            return HKQuantityType.quantityType(forIdentifier: .dietarySelenium)
        case .dietary_iodine:
            return HKQuantityType.quantityType(forIdentifier: .dietaryIodine)
        case .dietary_caffeine:
            return HKQuantityType.quantityType(forIdentifier: .dietaryCaffeine)
        case .dietary_water:
            return HKQuantityType.quantityType(forIdentifier: .dietaryWater)
            
        // MARK: - Reproductive Health - Menstrual Cycle
        case .menstrual_flow:
            return HKCategoryType.categoryType(forIdentifier: .menstrualFlow)
        case .intermenstrual_bleeding:
            return HKCategoryType.categoryType(forIdentifier: .intermenstrualBleeding)
        case .infrequent_menstrual_cycles:
            if #available(iOS 16.0, *) {
                return HKCategoryType.categoryType(forIdentifier: .infrequentMenstrualCycles)
            } else { return nil }
        case .irregular_menstrual_cycles:
            if #available(iOS 16.0, *) {
                return HKCategoryType.categoryType(forIdentifier: .irregularMenstrualCycles)
            } else { return nil }
        case .persistent_intermenstrual_bleeding:
            if #available(iOS 16.0, *) {
                return HKCategoryType.categoryType(forIdentifier: .persistentIntermenstrualBleeding)
            } else { return nil }
        case .prolonged_menstrual_periods:
            if #available(iOS 16.0, *) {
                return HKCategoryType.categoryType(forIdentifier: .prolongedMenstrualPeriods)
            } else { return nil }
            
        // MARK: - Reproductive Health - Fertility
        case .ovulation_test_result:
            return HKCategoryType.categoryType(forIdentifier: .ovulationTestResult)
        case .cervical_mucus_quality:
            return HKCategoryType.categoryType(forIdentifier: .cervicalMucusQuality)
            
        // MARK: - Reproductive Health - Sexual Activity
        case .sexual_activity:
            return HKCategoryType.categoryType(forIdentifier: .sexualActivity)
        case .contraceptive:
            if #available(iOS 14.3, *) {
                return HKCategoryType.categoryType(forIdentifier: .contraceptive)
            } else { return nil }
            
        // MARK: - Reproductive Health - Pregnancy
        case .pregnancy:
            if #available(iOS 14.3, *) {
                return HKCategoryType.categoryType(forIdentifier: .pregnancy)
            } else { return nil }
        case .pregnancy_test_result:
            if #available(iOS 15.0, *) {
                return HKCategoryType.categoryType(forIdentifier: .pregnancyTestResult)
            } else { return nil }
        case .progesterone_test_result:
            if #available(iOS 15.0, *) {
                return HKCategoryType.categoryType(forIdentifier: .progesteroneTestResult)
            } else { return nil }
        case .lactation:
            if #available(iOS 14.3, *) {
                return HKCategoryType.categoryType(forIdentifier: .lactation)
            } else { return nil }
            
        // MARK: - Reproductive Health - Symptoms
        case .abdominal_cramps:
            if #available(iOS 13.6, *) {
                return HKCategoryType.categoryType(forIdentifier: .abdominalCramps)
            } else { return nil }
        case .acne:
            if #available(iOS 13.6, *) {
                return HKCategoryType.categoryType(forIdentifier: .acne)
            } else { return nil }
        case .appetite_changes:
            if #available(iOS 13.6, *) {
                return HKCategoryType.categoryType(forIdentifier: .appetiteChanges)
            } else { return nil }
        case .bladder_incontinence:
            if #available(iOS 14.0, *) {
                return HKCategoryType.categoryType(forIdentifier: .bladderIncontinence)
            } else { return nil }
        case .bloating:
            if #available(iOS 13.6, *) {
                return HKCategoryType.categoryType(forIdentifier: .bloating)
            } else { return nil }
        case .breast_pain:
            if #available(iOS 13.6, *) {
                return HKCategoryType.categoryType(forIdentifier: .breastPain)
            } else { return nil }
        case .chills:
            if #available(iOS 13.6, *) {
                return HKCategoryType.categoryType(forIdentifier: .chills)
            } else { return nil }
        case .constipation:
            if #available(iOS 13.6, *) {
                return HKCategoryType.categoryType(forIdentifier: .constipation)
            } else { return nil }
        case .diarrhea:
            if #available(iOS 13.6, *) {
                return HKCategoryType.categoryType(forIdentifier: .diarrhea)
            } else { return nil }
        case .dizziness:
            if #available(iOS 13.6, *) {
                return HKCategoryType.categoryType(forIdentifier: .dizziness)
            } else { return nil }
        case .dry_skin:
            if #available(iOS 14.0, *) {
                return HKCategoryType.categoryType(forIdentifier: .drySkin)
            } else { return nil }
        case .fatigue:
            if #available(iOS 13.6, *) {
                return HKCategoryType.categoryType(forIdentifier: .fatigue)
            } else { return nil }
        case .hair_loss:
            if #available(iOS 14.0, *) {
                return HKCategoryType.categoryType(forIdentifier: .hairLoss)
            } else { return nil }
        case .headache:
            if #available(iOS 13.6, *) {
                return HKCategoryType.categoryType(forIdentifier: .headache)
            } else { return nil }
        case .hot_flashes:
            if #available(iOS 13.6, *) {
                return HKCategoryType.categoryType(forIdentifier: .hotFlashes)
            } else { return nil }
        case .lower_back_pain:
            if #available(iOS 13.6, *) {
                return HKCategoryType.categoryType(forIdentifier: .lowerBackPain)
            } else { return nil }
        case .memory_lapse:
            if #available(iOS 14.0, *) {
                return HKCategoryType.categoryType(forIdentifier: .memoryLapse)
            } else { return nil }
        case .mood_changes:
            if #available(iOS 13.6, *) {
                return HKCategoryType.categoryType(forIdentifier: .moodChanges)
            } else { return nil }
        case .nausea:
            if #available(iOS 13.6, *) {
                return HKCategoryType.categoryType(forIdentifier: .nausea)
            } else { return nil }
        case .night_sweats:
            if #available(iOS 14.0, *) {
                return HKCategoryType.categoryType(forIdentifier: .nightSweats)
            } else { return nil }
        case .pelvic_pain:
            if #available(iOS 13.6, *) {
                return HKCategoryType.categoryType(forIdentifier: .pelvicPain)
            } else { return nil }
        case .rapid_pounding_or_fluttering_heartbeat:
            if #available(iOS 13.6, *) {
                return HKCategoryType.categoryType(forIdentifier: .rapidPoundingOrFlutteringHeartbeat)
            } else { return nil }
        case .runny_nose:
            if #available(iOS 13.6, *) {
                return HKCategoryType.categoryType(forIdentifier: .runnyNose)
            } else { return nil }
        case .sinus_congestion:
            if #available(iOS 13.6, *) {
                return HKCategoryType.categoryType(forIdentifier: .sinusCongestion)
            } else { return nil }
        case .skipped_heartbeat:
            if #available(iOS 13.6, *) {
                return HKCategoryType.categoryType(forIdentifier: .skippedHeartbeat)
            } else { return nil }
        case .sleep_changes:
            if #available(iOS 13.6, *) {
                return HKCategoryType.categoryType(forIdentifier: .sleepChanges)
            } else { return nil }
        case .sore_throat:
            if #available(iOS 13.6, *) {
                return HKCategoryType.categoryType(forIdentifier: .soreThroat)
            } else { return nil }
        case .vaginal_dryness:
            if #available(iOS 14.0, *) {
                return HKCategoryType.categoryType(forIdentifier: .vaginalDryness)
            } else { return nil }
        case .vomiting:
            if #available(iOS 13.6, *) {
                return HKCategoryType.categoryType(forIdentifier: .vomiting)
            } else { return nil }

        // MARK: - Umbrella (no single HK type; expanded to granular sensors before use)
        case .nutrition, .reproductive:
            return nil
        }
    }
}
