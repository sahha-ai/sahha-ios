extension SahhaSensor {
    var unitString: String {
        switch self {
        case .heart_rate, .resting_heart_rate, .walking_heart_rate_average:
            return "bpm"
        case .heart_rate_variability_sdnn, .running_ground_contact_time:
            return "ms"
        case .vo2_max:
            return "ml/kg/min"
        case .oxygen_saturation, .body_fat, .walking_steadiness, .walking_asymmetry_percentage, .walking_double_support_percentage:
            return "percent"
        case .respiratory_rate:
            return "bps"
        case .active_energy_burned, .basal_energy_burned:
            return "kcal"
        case .sleep, .time_in_daylight, .stand_time, .move_time, .exercise_time, .exercise:
            return "minute"
        case .body_temperature, .basal_body_temperature, .sleeping_wrist_temperature:
            return "degC"
        case .height, .waist_circumference, .running_stride_length, .six_minute_walk_test_distance, .walking_step_length:
            return "m"
        case .running_vertical_oscillation:
            return "cm"
        case .stair_ascent_speed, .stair_descent_speed, .walking_speed, .running_speed:
            return "m/s"
        case .running_power:
            return "watt"
        case .weight, .lean_body_mass:
            return "kg"
        case .blood_pressure_systolic, .blood_pressure_diastolic:
            return "mmHg"
        case .blood_glucose:
            return "mg/dL"
        case .steps, .floors_climbed, .body_mass_index, .activity_summary:
            return "count"
        case .gender, .date_of_birth, .device_lock,
             .heart_rate_variability_rmssd, .total_energy_burned,
             .basal_metabolic_rate, .body_water_mass, .bone_mass:
            return ""
        }
    }
}
