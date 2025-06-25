extension SahhaSensor {
    var logType: LogType {
        return switch self {
        case .gender, .date_of_birth:
            .demographic
        case .sleep:
            .sleep
        case .steps, .floors_climbed, .move_time, .stand_time, .exercise_time, .activity_summary, .walking_asymmetry_percentage, .walking_speed,
            .walking_steadiness, .walking_double_support_percentage, .walking_step_length, .running_speed, .running_power,
            .running_ground_contact_time, .running_stride_length, .running_vertical_oscillation, .six_minute_walk_test_distance, .stair_ascent_speed,
            .stair_descent_speed:
            .activity
        case .heart_rate, .resting_heart_rate, .walking_heart_rate_average, .heart_rate_variability_sdnn, .heart_rate_variability_rmssd:
            .heart
        case .blood_pressure_systolic, .blood_pressure_diastolic, .blood_glucose:
            .blood
        case .oxygen_saturation, .vo2_max, .respiratory_rate:
            .oxygen
        case .active_energy_burned, .basal_energy_burned, .total_energy_burned, .basal_metabolic_rate, .time_in_daylight:
            .energy
        case .body_temperature, .basal_body_temperature, .sleeping_wrist_temperature:
            .temperature
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
