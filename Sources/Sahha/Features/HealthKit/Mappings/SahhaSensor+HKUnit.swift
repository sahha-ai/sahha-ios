import HealthKit

extension SahhaSensor {
    var hkUnit: HKUnit? {
        switch self {
        case .active_energy_burned:
            return .largeCalorie()
        case .activity_summary:
            return nil
        case .basal_body_temperature:
            return .degreeCelsius()
        case .basal_energy_burned:
            return .largeCalorie()
        case .basal_metabolic_rate:
            return nil
        case .blood_glucose:
            return HKUnit(from: "mg/dL")
        case .blood_pressure_diastolic:
            return .millimeterOfMercury()
        case .blood_pressure_systolic:
            return .millimeterOfMercury()
        case .body_fat:
            return .percent()
        case .body_mass_index:
            return .count()
        case .body_temperature:
            return .degreeCelsius()
        case .body_water_mass:
            return nil
        case .bone_mass:
            return nil
        case .date_of_birth:
            return nil
        case .device_lock:
            return nil
        case .energy_consumed:
            return .largeCalorie()
        case .exercise:
            return nil
        case .exercise_time:
            return .minute()
        case .floors_climbed:
            return .count()
        case .gender:
            return nil
        case .heart_rate:
            return .count().unitDivided(by: .minute())
        case .heart_rate_variability_rmssd:
            return nil
        case .heart_rate_variability_sdnn:
            return .secondUnit(with: .milli)
        case .height:
            return .meter()
        case .lean_body_mass:
            return .gramUnit(with: .kilo)
        case .move_time:
            return .minute()
        case .oxygen_saturation:
            return .percent()
        case .resting_heart_rate:
            return .count().unitDivided(by: .minute())
        case .respiratory_rate:
            return .count().unitDivided(by: .second())
        case .running_ground_contact_time:
            return .secondUnit(with: .milli)
        case .running_power:
            guard #available(iOS 16.0, *) else { return nil }
            return .watt()
        case .running_speed:
            return .meter().unitDivided(by: .second())
        case .running_stride_length:
            return .meter()
        case .running_vertical_oscillation:
            return .meterUnit(with: .centi)
        case .six_minute_walk_test_distance:
            return .meter()
        case .sleep:
            return .count()
        case .sleeping_wrist_temperature:
            return .degreeCelsius()
        case .stair_ascent_speed:
            return .meter().unitDivided(by: .second())
        case .stair_descent_speed:
            return .meter().unitDivided(by: .second())
        case .stand_time:
            return .minute()
        case .steps:
            return .count()
        case .time_in_daylight:
            return .minute()
        case .total_energy_burned:
            return nil
        case .vo2_max:
            return HKUnit(from: "ml/kg*min")
        case .waist_circumference:
            return .meter()
        case .walking_asymmetry_percentage:
            return .percent()
        case .walking_double_support_percentage:
            return .percent()
        case .walking_heart_rate_average:
            return .count().unitDivided(by: .minute())
        case .walking_speed:
            return .meter().unitDivided(by: .second())
        case .walking_steadiness:
            return .percent()
        case .walking_step_length:
            return .meter()
        case .weight:
            return .gramUnit(with: .kilo)
        }
    }
}
