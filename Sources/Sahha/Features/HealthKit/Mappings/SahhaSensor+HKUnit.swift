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
        case .walking_speed:
            return .meter().unitDivided(by: .second())
        case .walking_step_length, .running_stride_length, .stair_ascent_speed, .stair_descent_speed, .six_minute_walk_test_distance:
            return .meter()
        case .running_speed:
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
        }
    }
}
