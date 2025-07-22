import HealthKit

extension SahhaSensor {
    var hkObjectType: HKObjectType? {
        switch self {
        case .activity_summary:
            return HKSampleType.activitySummaryType()
        case .active_energy_burned:
            return HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        case .basal_body_temperature:
            return HKQuantityType.quantityType(forIdentifier: .basalBodyTemperature)
        case .basal_energy_burned:
            return HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)
        case .basal_metabolic_rate:
            return nil
        case .blood_glucose:
            return HKQuantityType.quantityType(forIdentifier: .bloodGlucose)
        case .blood_pressure_diastolic:
            return HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)
        case .blood_pressure_systolic:
            return HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)
        case .body_fat:
            return HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)
        case .body_mass_index:
            return HKQuantityType.quantityType(forIdentifier: .bodyMassIndex)
        case .body_temperature:
            return HKQuantityType.quantityType(forIdentifier: .bodyTemperature)
        case .body_water_mass:
            return nil
        case .bone_mass:
            return nil
        case .date_of_birth:
            return HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth)
        case .device_lock:
            return nil
        case .energy_consumed:
            return HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)
        case .exercise:
            return HKWorkoutType.workoutType()
        case .exercise_time:
            return HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)
        case .floors_climbed:
            return HKQuantityType.quantityType(forIdentifier: .flightsClimbed)
        case .gender:
            return HKCharacteristicType.characteristicType(forIdentifier: .biologicalSex)
        case .heart_rate:
            return HKQuantityType.quantityType(forIdentifier: .heartRate)
        case .heart_rate_variability_rmssd:
            return nil
        case .heart_rate_variability_sdnn:
            return HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
        case .height:
            return HKQuantityType.quantityType(forIdentifier: .height)
        case .lean_body_mass:
            return HKQuantityType.quantityType(forIdentifier: .leanBodyMass)
        case .move_time:
            return HKQuantityType.quantityType(forIdentifier: .appleMoveTime)
        case .oxygen_saturation:
            return HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)
        case .resting_heart_rate:
            return HKQuantityType.quantityType(forIdentifier: .restingHeartRate)
        case .respiratory_rate:
            return HKQuantityType.quantityType(forIdentifier: .respiratoryRate)
        case .running_ground_contact_time:
            guard #available(iOS 16.0, *) else { return nil }
            return HKQuantityType.quantityType(forIdentifier: .runningGroundContactTime)
        case .running_power:
            guard #available(iOS 16.0, *) else { return nil }
            return HKQuantityType.quantityType(forIdentifier: .runningPower)
        case .running_speed:
            guard #available(iOS 16.0, *) else { return nil }
            return HKQuantityType.quantityType(forIdentifier: .runningSpeed)
        case .running_stride_length:
            guard #available(iOS 16.0, *) else { return nil }
            return HKQuantityType.quantityType(forIdentifier: .runningStrideLength)
        case .running_vertical_oscillation:
            guard #available(iOS 16.0, *) else { return nil }
            return HKQuantityType.quantityType(forIdentifier: .runningVerticalOscillation)
        case .six_minute_walk_test_distance:
            return HKQuantityType.quantityType(forIdentifier: .sixMinuteWalkTestDistance)
        case .sleep:
            return HKSampleType.categoryType(forIdentifier: .sleepAnalysis)
        case .sleeping_wrist_temperature:
            guard #available(iOS 16.0, *) else { return nil }
            return HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature)
        case .stand_time:
            return HKQuantityType.quantityType(forIdentifier: .appleStandTime)
        case .stair_ascent_speed:
            return HKQuantityType.quantityType(forIdentifier: .stairAscentSpeed)
        case .stair_descent_speed:
            return HKQuantityType.quantityType(forIdentifier: .stairDescentSpeed)
        case .steps:
            return HKQuantityType.quantityType(forIdentifier: .stepCount)
        case .time_in_daylight:
            guard #available(iOS 17.0, *) else { return nil }
            return HKQuantityType.quantityType(forIdentifier: .timeInDaylight)
        case .total_energy_burned:
            return nil
        case .vo2_max:
            return HKQuantityType.quantityType(forIdentifier: .vo2Max)
        case .waist_circumference:
            return HKQuantityType.quantityType(forIdentifier: .waistCircumference)
        case .walking_asymmetry_percentage:
            return HKQuantityType.quantityType(forIdentifier: .walkingAsymmetryPercentage)
        case .walking_double_support_percentage:
            return HKQuantityType.quantityType(forIdentifier: .walkingDoubleSupportPercentage)
        case .walking_heart_rate_average:
            return HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage)
        case .walking_speed:
            return HKQuantityType.quantityType(forIdentifier: .walkingSpeed)
        case .walking_steadiness:
            return HKQuantityType.quantityType(forIdentifier: .appleWalkingSteadiness)
        case .walking_step_length:
            return HKQuantityType.quantityType(forIdentifier: .walkingStepLength)
        case .weight:
            return HKQuantityType.quantityType(forIdentifier: .bodyMass)
        }
    }
}
