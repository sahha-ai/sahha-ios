extension SahhaSensor {
    var unitString: String {
        return switch self {
        case .heart_rate, .resting_heart_rate, .walking_heart_rate_average:
            "bpm"
        case .heart_rate_variability_sdnn, .running_ground_contact_time:
            "ms"
        case .vo2_max:
            "ml/kg/min"
        case .oxygen_saturation, .body_fat, .walking_steadiness, .walking_asymmetry_percentage, .walking_double_support_percentage:
            "percent"
        case .respiratory_rate:
            "bps"
        case .active_energy_burned, .basal_energy_burned, .energy_consumed:
            "kcal"
        case .sleep, .time_in_daylight, .stand_time, .move_time, .exercise_time, .exercise:
            "minute"
        case .body_temperature, .basal_body_temperature, .sleeping_wrist_temperature:
            "degC"
        case .height, .waist_circumference, .running_stride_length, .six_minute_walk_test_distance, .walking_step_length:
            "m"
        case .running_vertical_oscillation:
            "cm"
        case .stair_ascent_speed, .stair_descent_speed, .walking_speed, .running_speed:
            "m/s"
        case .running_power:
            "watt"
        case .weight, .lean_body_mass:
            "kg"
        case .blood_pressure_systolic, .blood_pressure_diastolic:
            "mmHg"
        case .blood_glucose:
            "mg/dL"
        case .steps, .floors_climbed, .body_mass_index, .activity_summary:
            "count"
        case .gender, .date_of_birth, .device_lock, .heart_rate_variability_rmssd,
            .total_energy_burned, .basal_metabolic_rate, .body_water_mass, .bone_mass:
            ""
        }
    }
}
