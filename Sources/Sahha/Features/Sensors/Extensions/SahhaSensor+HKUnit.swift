import HealthKit

extension SahhaSensor {
    var hkUnit: HKUnit? {
        switch self {
        case .heart_rate, .resting_heart_rate, .walking_heart_rate_average:
            return .count().unitDivided(by: .minute())
        case .heart_rate_variability_sdnn, .running_ground_contact_time:
            return .secondUnit(with: .milli)
        case .vo2_max:
            return HKUnit(from: "ml/kg*min")
        case .oxygen_saturation, .body_fat, .walking_steadiness, .walking_asymmetry_percentage, .walking_double_support_percentage:
            return .percent()
        case .respiratory_rate:
            return .count().unitDivided(by: .second())
        case .active_energy_burned, .basal_energy_burned, .energy_consumed:
            return .largeCalorie()
        case .time_in_daylight, .stand_time, .move_time, .exercise_time:
            return .minute()
        case .body_temperature, .basal_body_temperature, .sleeping_wrist_temperature:
            return .degreeCelsius()
        case .height, .waist_circumference, .running_stride_length, .six_minute_walk_test_distance, .walking_step_length:
            return .meter()
        case .running_vertical_oscillation:
            return .meterUnit(with: .centi)
        case .stair_ascent_speed, .stair_descent_speed, .walking_speed, .running_speed:
            return .meter().unitDivided(by: .second())
        case .running_power:
            guard #available(iOS 16.0, *) else { return nil }
            return .watt()
        case .weight, .lean_body_mass:
            return .gramUnit(with: .kilo)
        case .blood_pressure_systolic, .blood_pressure_diastolic:
            return .millimeterOfMercury()
        case .blood_glucose:
            return HKUnit(from: "mg/dL")
        case .sleep, .steps, .floors_climbed, .body_mass_index:
            return .count()
        case .gender, .date_of_birth, .device_lock, .exercise, .heart_rate_variability_rmssd, .activity_summary, .total_energy_burned,
            .basal_metabolic_rate, .body_water_mass, .bone_mass:
            return nil
        }
    }
}
