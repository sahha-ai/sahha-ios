extension SahhaSensor {
    var category: SahhaBiomarkerCategory {
        return switch self {
        case .gender, .date_of_birth:
            .characteristic
        case .sleep:
            .sleep
        case .steps, .floors_climbed, .move_time, .stand_time, .exercise_time, .activity_summary,
            .active_energy_burned, .basal_energy_burned, .total_energy_burned, .basal_metabolic_rate,
            .time_in_daylight, .walking_steadiness, .running_ground_contact_time, .running_speed,
            .running_power, .running_stride_length, .running_vertical_oscillation, .six_minute_walk_test_distance,
            .stair_ascent_speed, .stair_descent_speed, .walking_asymmetry_percentage, .walking_double_support_percentage,
            .walking_speed, .walking_step_length:
            .activity
        case .heart_rate, .resting_heart_rate, .walking_heart_rate_average, .heart_rate_variability_sdnn, .heart_rate_variability_rmssd,
            .blood_pressure_systolic, .blood_pressure_diastolic, .blood_glucose, .oxygen_saturation, .vo2_max, .respiratory_rate, .body_temperature,
            .basal_body_temperature, .sleeping_wrist_temperature:
            .vitals
        case .height, .weight, .lean_body_mass, .body_mass_index, .body_fat, .waist_circumference, .body_water_mass, .bone_mass:
            .body
        case .device_lock:
            .device
        case .exercise:
            .exercise
        case .energy_consumed:
            .nutrition
        }
    }
}
