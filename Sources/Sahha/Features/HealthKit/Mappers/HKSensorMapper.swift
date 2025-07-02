import HealthKit

struct HKSensorMapper {
    private static let sensorToObjectType: [SahhaSensor: HKObjectType] = {
        var map: [SahhaSensor: HKObjectType] = [
            .steps: HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            .floors_climbed: HKQuantityType.quantityType(forIdentifier: .flightsClimbed)!,
            .heart_rate: HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            .resting_heart_rate: HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!,
            .walking_heart_rate_average: HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage)!,
            .heart_rate_variability_sdnn: HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            .blood_pressure_systolic: HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)!,
            .blood_pressure_diastolic: HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
            .blood_glucose: HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!,
            .vo2_max: HKQuantityType.quantityType(forIdentifier: .vo2Max)!,
            .oxygen_saturation: HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!,
            .respiratory_rate: HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!,
            .active_energy_burned: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            .basal_energy_burned: HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!,
            .body_temperature: HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!,
            .basal_body_temperature: HKQuantityType.quantityType(forIdentifier: .basalBodyTemperature)!,
            .height: HKQuantityType.quantityType(forIdentifier: .height)!,
            .weight: HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
            .lean_body_mass: HKQuantityType.quantityType(forIdentifier: .leanBodyMass)!,
            .body_mass_index: HKQuantityType.quantityType(forIdentifier: .bodyMassIndex)!,
            .body_fat: HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!,
            .waist_circumference: HKQuantityType.quantityType(forIdentifier: .waistCircumference)!,
            .stand_time: HKQuantityType.quantityType(forIdentifier: .appleStandTime)!,
            .exercise_time: HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!,
            .energy_consumed: HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
            .sleep: HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
            .exercise: HKWorkoutType.workoutType(),
            .gender: HKCharacteristicType.characteristicType(forIdentifier: .biologicalSex)!,
            .date_of_birth: HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth)!,
            .activity_summary: HKSampleType.activitySummaryType(),
            // iOS 14.0 mappings (available in iOS 15)
            .six_minute_walk_test_distance: HKQuantityType.quantityType(forIdentifier: .sixMinuteWalkTestDistance)!,
            .stair_ascent_speed: HKQuantityType.quantityType(forIdentifier: .stairAscentSpeed)!,
            .stair_descent_speed: HKQuantityType.quantityType(forIdentifier: .stairDescentSpeed)!,
            .walking_speed: HKQuantityType.quantityType(forIdentifier: .walkingSpeed)!,
            .walking_asymmetry_percentage: HKQuantityType.quantityType(forIdentifier: .walkingAsymmetryPercentage)!,
            .walking_double_support_percentage: HKQuantityType.quantityType(forIdentifier: .walkingDoubleSupportPercentage)!,
            .walking_step_length: HKQuantityType.quantityType(forIdentifier: .walkingStepLength)!,
            // iOS 14.5 mappings (available in iOS 15)
            .move_time: HKQuantityType.quantityType(forIdentifier: .appleMoveTime)!,
            // iOS 15.0 mappings
            .walking_steadiness: HKQuantityType.quantityType(forIdentifier: .appleWalkingSteadiness)!
        ]

        if #available(iOS 16.0, *) {
            let iOS16Mappings: [SahhaSensor: HKObjectType] = [
                .sleeping_wrist_temperature: HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature)!,
                .running_speed: HKQuantityType.quantityType(forIdentifier: .runningSpeed)!,
                .running_power: HKQuantityType.quantityType(forIdentifier: .runningPower)!,
                .running_ground_contact_time: HKQuantityType.quantityType(forIdentifier: .runningGroundContactTime)!,
                .running_stride_length: HKQuantityType.quantityType(forIdentifier: .runningStrideLength)!,
                .running_vertical_oscillation: HKQuantityType.quantityType(forIdentifier: .runningVerticalOscillation)!
            ]
            map.merge(iOS16Mappings) { (_, new) in new }
        }

        if #available(iOS 17.0, *) {
            let iOS17Mappings: [SahhaSensor: HKObjectType] = [
                .time_in_daylight: HKQuantityType.quantityType(forIdentifier: .timeInDaylight)!
            ]
            map.merge(iOS17Mappings) { (_, new) in new }
        }

        return map
    }()

    private static let sampleToSensorMap: [String: SahhaSensor] = {
        var map: [String: SahhaSensor] = [:]
        for (sensor, objectType) in sensorToObjectType {
            map[objectType.identifier] = sensor
        }
        return map
    }()

    static func objectType(for sensor: SahhaSensor) -> HKObjectType? {
        return sensorToObjectType[sensor]
    }

    static func sahhaSensor(for objectType: HKObjectType) -> SahhaSensor? {
        return sampleToSensorMap[objectType.identifier]
    }
}
