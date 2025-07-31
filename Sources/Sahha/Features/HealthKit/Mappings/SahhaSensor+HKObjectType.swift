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
        case .energy_consumed:
            return HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)
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
        }
    }
}
