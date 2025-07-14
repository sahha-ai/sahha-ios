import HealthKit

struct SensorMetadata {
    let sensor: SahhaSensor
    let hkObjectType: HKObjectType?
    let hkUnit: HKUnit?
    let unitString: String
    let logType: LogType
    let biomarkerCategory: SahhaBiomarkerCategory
    let statsOptions: HKStatisticsOptions
}

enum SensorMapper {
    // MARK: Demographic
    private static let demographicSensorMetaData: [SahhaSensor: SensorMetadata] = [
        .gender: .init(
            sensor: .gender,
            hkObjectType: HKCharacteristicType.characteristicType(forIdentifier: .biologicalSex),
            hkUnit: nil,
            unitString: "",
            logType: .demographic,
            biomarkerCategory: .characteristic,
            statsOptions: .cumulativeSum
        ),
        .date_of_birth: .init(
            sensor: .date_of_birth,
            hkObjectType: HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth),
            hkUnit: nil,
            unitString: "",
            logType: .demographic,
            biomarkerCategory: .characteristic,
            statsOptions: .cumulativeSum
        ),
    ]

    // MARK: Sleep
    private static let sleepSensorMetaData: [SahhaSensor: SensorMetadata] = [
        .sleep: .init(
            sensor: .sleep,
            hkObjectType: HKCategoryType.categoryType(forIdentifier: .sleepAnalysis),
            hkUnit: .minute(),
            unitString: "minute",
            logType: .sleep,
            biomarkerCategory: .sleep,
            statsOptions: .cumulativeSum
        )
    ]

    // MARK: Activity
    private static let activitySensorMetaData: [SahhaSensor: SensorMetadata] = [
        .steps: .init(
            sensor: .steps,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .stepCount),
            hkUnit: .count(),
            unitString: "count",
            logType: .activity,
            biomarkerCategory: .activity,
            statsOptions: .cumulativeSum
        ),
        .floors_climbed: .init(
            sensor: .floors_climbed,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .flightsClimbed),
            hkUnit: .count(),
            unitString: "count",
            logType: .activity,
            biomarkerCategory: .activity,
            statsOptions: .cumulativeSum
        ),
        .move_time: .init(
            sensor: .move_time,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .appleMoveTime),
            hkUnit: .minute(),
            unitString: "minute",
            logType: .activity,
            biomarkerCategory: .activity,
            statsOptions: .cumulativeSum
        ),
        .stand_time: .init(
            sensor: .stand_time,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .appleStandTime),
            hkUnit: .minute(),
            unitString: "minute",
            logType: .activity,
            biomarkerCategory: .activity,
            statsOptions: .cumulativeSum
        ),
        .exercise_time: .init(
            sensor: .exercise_time,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .appleExerciseTime),
            hkUnit: .minute(),
            unitString: "minute",
            logType: .activity,
            biomarkerCategory: .activity,
            statsOptions: .cumulativeSum
        ),
        .activity_summary: .init(
            sensor: .activity_summary,
            hkObjectType: HKSampleType.activitySummaryType(),
            hkUnit: .count(),
            unitString: "count",
            logType: .activity,
            biomarkerCategory: .activity,
            statsOptions: .cumulativeSum
        ),
        .walking_asymmetry_percentage: .init(
            sensor: .walking_asymmetry_percentage,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .walkingAsymmetryPercentage),
            hkUnit: .percent(),
            unitString: "percent",
            logType: .activity,
            biomarkerCategory: .activity,
            statsOptions: .discreteAverage
        ),
        .walking_speed: .init(
            sensor: .walking_speed,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .walkingSpeed),
            hkUnit: .meter().unitDivided(by: .second()),
            unitString: "m/s",
            logType: .activity,
            biomarkerCategory: .activity,
            statsOptions: .discreteAverage
        ),
        .walking_steadiness: .init(
            sensor: .walking_steadiness,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .appleWalkingSteadiness),
            hkUnit: .percent(),
            unitString: "percent",
            logType: .activity,
            biomarkerCategory: .activity,
            statsOptions: .discreteAverage
        ),
        .walking_double_support_percentage: .init(
            sensor: .walking_double_support_percentage,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .walkingDoubleSupportPercentage),
            hkUnit: .percent(),
            unitString: "percent",
            logType: .activity,
            biomarkerCategory: .activity,
            statsOptions: .discreteAverage
        ),
        .walking_step_length: .init(
            sensor: .walking_step_length,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .walkingStepLength),
            hkUnit: .meter(),
            unitString: "m",
            logType: .activity,
            biomarkerCategory: .activity,
            statsOptions: .discreteAverage
        ),
        .six_minute_walk_test_distance: .init(
            sensor: .six_minute_walk_test_distance,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .sixMinuteWalkTestDistance),
            hkUnit: .meter(),
            unitString: "m",
            logType: .activity,
            biomarkerCategory: .activity,
            statsOptions: .discreteAverage
        ),
        .stair_ascent_speed: .init(
            sensor: .stair_ascent_speed,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .stairAscentSpeed),
            hkUnit: .meter().unitDivided(by: .second()),
            unitString: "m/s",
            logType: .activity,
            biomarkerCategory: .activity,
            statsOptions: .discreteAverage
        ),
        .stair_descent_speed: .init(
            sensor: .stair_descent_speed,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .stairDescentSpeed),
            hkUnit: .meter().unitDivided(by: .second()),
            unitString: "m/s",
            logType: .activity,
            biomarkerCategory: .activity,
            statsOptions: .discreteAverage
        ),
    ]

    // MARK: Activity (iOS 16)
    @available(iOS 16.0, *)
    private static let iOS16ActivitySensorMetadata: [SahhaSensor: SensorMetadata] = [
        .running_speed: .init(
            sensor: .running_speed,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .runningSpeed),
            hkUnit: .meter().unitDivided(by: .second()),
            unitString: "m/s",
            logType: .activity,
            biomarkerCategory: .activity,
            statsOptions: .discreteAverage
        ),
        .running_power: .init(
            sensor: .running_power,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .runningPower),
            hkUnit: .watt(),
            unitString: "watt",
            logType: .activity,
            biomarkerCategory: .activity,
            statsOptions: .discreteAverage
        ),
        .running_ground_contact_time: .init(
            sensor: .running_ground_contact_time,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .runningGroundContactTime),
            hkUnit: .secondUnit(with: .milli),
            unitString: "ms",
            logType: .activity,
            biomarkerCategory: .activity,
            statsOptions: .discreteAverage
        ),
        .running_stride_length: .init(
            sensor: .running_stride_length,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .runningStrideLength),
            hkUnit: .meter(),
            unitString: "m",
            logType: .activity,
            biomarkerCategory: .activity,
            statsOptions: .discreteAverage
        ),
        .running_vertical_oscillation: .init(
            sensor: .running_vertical_oscillation,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .runningVerticalOscillation),
            hkUnit: .meterUnit(with: .centi),
            unitString: "cm",
            logType: .activity,
            biomarkerCategory: .activity,
            statsOptions: .discreteAverage
        ),
    ]

    // MARK: Heart
    private static let heartSensorMetadata: [SahhaSensor: SensorMetadata] = [
        .heart_rate: .init(
            sensor: .heart_rate,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .heartRate),
            hkUnit: .count().unitDivided(by: .minute()),
            unitString: "bpm",
            logType: .heart,
            biomarkerCategory: .vitals,
            statsOptions: .discreteAverage
        ),
        .resting_heart_rate: .init(
            sensor: .resting_heart_rate,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .restingHeartRate),
            hkUnit: .count().unitDivided(by: .minute()),
            unitString: "bpm",
            logType: .heart,
            biomarkerCategory: .vitals,
            statsOptions: .discreteAverage
        ),
        .walking_heart_rate_average: .init(
            sensor: .walking_heart_rate_average,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage),
            hkUnit: .count().unitDivided(by: .minute()),
            unitString: "bpm",
            logType: .heart,
            biomarkerCategory: .vitals,
            statsOptions: .discreteAverage
        ),
        .heart_rate_variability_sdnn: .init(
            sensor: .heart_rate_variability_sdnn,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
            hkUnit: .secondUnit(with: .milli),
            unitString: "ms",
            logType: .heart,
            biomarkerCategory: .vitals,
            statsOptions: .discreteAverage
        ),
        .heart_rate_variability_rmssd: .init(
            sensor: .heart_rate_variability_rmssd,
            hkObjectType: nil,
            hkUnit: nil,
            unitString: "",
            logType: .heart,
            biomarkerCategory: .vitals,
            statsOptions: .cumulativeSum
        ),
    ]

    // MARK: Blood
    private static let bloodSensorMetadata: [SahhaSensor: SensorMetadata] = [
        .blood_pressure_systolic: .init(
            sensor: .blood_pressure_systolic,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
            hkUnit: .millimeterOfMercury(),
            unitString: "mmHg",
            logType: .blood,
            biomarkerCategory: .vitals,
            statsOptions: .discreteAverage
        ),
        .blood_pressure_diastolic: .init(
            sensor: .blood_pressure_diastolic,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic),
            hkUnit: .millimeterOfMercury(),
            unitString: "mmHg",
            logType: .blood,
            biomarkerCategory: .vitals,
            statsOptions: .discreteAverage
        ),
        .blood_glucose: .init(
            sensor: .blood_glucose,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .bloodGlucose),
            hkUnit: HKUnit(from: "mg/dL"),
            unitString: "mg/dL",
            logType: .blood,
            biomarkerCategory: .vitals,
            statsOptions: .discreteAverage
        ),
    ]

    // MARK: Oxygen
    private static let oxygenSensorMetaData: [SahhaSensor: SensorMetadata] = [
        .vo2_max: .init(
            sensor: .vo2_max,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .vo2Max),
            hkUnit: HKUnit(from: "ml/kg*min"),
            unitString: "ml/kg/min",
            logType: .oxygen,
            biomarkerCategory: .vitals,
            statsOptions: .discreteAverage
        ),
        .oxygen_saturation: .init(
            sensor: .oxygen_saturation,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .oxygenSaturation),
            hkUnit: .percent(),
            unitString: "percent",
            logType: .oxygen,
            biomarkerCategory: .vitals,
            statsOptions: .discreteAverage
        ),
        .respiratory_rate: .init(
            sensor: .respiratory_rate,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .respiratoryRate),
            hkUnit: .count().unitDivided(by: .second()),
            unitString: "bps",
            logType: .oxygen,
            biomarkerCategory: .vitals,
            statsOptions: .discreteAverage
        ),
    ]

    // MARK: Energy
    private static let energySensorMetadata: [SahhaSensor: SensorMetadata] = [
        .active_energy_burned: .init(
            sensor: .active_energy_burned,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
            hkUnit: .largeCalorie(),
            unitString: "kcal",
            logType: .energy,
            biomarkerCategory: .activity,
            statsOptions: .cumulativeSum
        ),
        .basal_energy_burned: .init(
            sensor: .basal_energy_burned,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned),
            hkUnit: .largeCalorie(),
            unitString: "kcal",
            logType: .energy,
            biomarkerCategory: .activity,
            statsOptions: .cumulativeSum
        ),
        .total_energy_burned: .init(
            sensor: .total_energy_burned,
            hkObjectType: nil,
            hkUnit: nil,
            unitString: "",
            logType: .energy,
            biomarkerCategory: .activity,
            statsOptions: .cumulativeSum
        ),
        .basal_metabolic_rate: .init(
            sensor: .basal_metabolic_rate,
            hkObjectType: nil,
            hkUnit: nil,
            unitString: "",
            logType: .energy,
            biomarkerCategory: .activity,
            statsOptions: .discreteAverage
        ),
    ]

    // MARK: Energy (iOS 17)
    @available(iOS 17.0, *)
    private static let iOS17EnergySensorMetadata: [SahhaSensor: SensorMetadata] = [
        .time_in_daylight: .init(
            sensor: .time_in_daylight,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .timeInDaylight),
            hkUnit: .minute(),
            unitString: "minute",
            logType: .energy,
            biomarkerCategory: .activity,
            statsOptions: .cumulativeSum
        )
    ]

    // MARK: Temperature
    private static let temperatureSensorMetadata: [SahhaSensor: SensorMetadata] = [
        .body_temperature: .init(
            sensor: .body_temperature,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .bodyTemperature),
            hkUnit: .degreeCelsius(),
            unitString: "degC",
            logType: .temperature,
            biomarkerCategory: .vitals,
            statsOptions: .discreteAverage
        ),
        .basal_body_temperature: .init(
            sensor: .basal_body_temperature,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .basalBodyTemperature),
            hkUnit: .degreeCelsius(),
            unitString: "degC",
            logType: .temperature,
            biomarkerCategory: .vitals,
            statsOptions: .discreteAverage
        ),

    ]

    // MARK: Temperature (iOS 16)
    @available(iOS 16.0, *)
    private static let iOS16TemperatureSensorMetadata: [SahhaSensor: SensorMetadata] = [
        .sleeping_wrist_temperature: .init(
            sensor: .sleeping_wrist_temperature,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature),
            hkUnit: .degreeCelsius(),
            unitString: "degC",
            logType: .temperature,
            biomarkerCategory: .vitals,
            statsOptions: .discreteAverage
        )
    ]

    // MARK: Body
    private static let bodySensorMetadata: [SahhaSensor: SensorMetadata] = [
        .height: .init(
            sensor: .height,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .height),
            hkUnit: .meter(),
            unitString: "m",
            logType: .body,
            biomarkerCategory: .body,
            statsOptions: .discreteAverage
        ),
        .weight: .init(
            sensor: .weight,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .bodyMass),
            hkUnit: .gramUnit(with: .kilo),
            unitString: "kg",
            logType: .body,
            biomarkerCategory: .body,
            statsOptions: .discreteAverage
        ),
        .lean_body_mass: .init(
            sensor: .lean_body_mass,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .leanBodyMass),
            hkUnit: .gramUnit(with: .kilo),
            unitString: "kg",
            logType: .body,
            biomarkerCategory: .body,
            statsOptions: .discreteAverage
        ),
        .body_mass_index: .init(
            sensor: .body_mass_index,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .bodyMassIndex),
            hkUnit: .count(),
            unitString: "count",
            logType: .body,
            biomarkerCategory: .body,
            statsOptions: .discreteAverage
        ),
        .body_fat: .init(
            sensor: .body_fat,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage),
            hkUnit: .percent(),
            unitString: "percent",
            logType: .body,
            biomarkerCategory: .body,
            statsOptions: .discreteAverage
        ),
        .waist_circumference: .init(
            sensor: .waist_circumference,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .waistCircumference),
            hkUnit: .meter(),
            unitString: "m",
            logType: .body,
            biomarkerCategory: .body,
            statsOptions: .discreteAverage
        ),
        .body_water_mass: .init(
            sensor: .body_water_mass,
            hkObjectType: nil,
            hkUnit: nil,
            unitString: "",
            logType: .body,
            biomarkerCategory: .body,
            statsOptions: .discreteAverage
        ),
        .bone_mass: .init(
            sensor: .bone_mass,
            hkObjectType: nil,
            hkUnit: nil,
            unitString: "",
            logType: .body,
            biomarkerCategory: .body,
            statsOptions: .discreteAverage
        ),
    ]

    // MARK: Device
    private static let deviceSensorMetadata: [SahhaSensor: SensorMetadata] = [
        .device_lock: .init(
            sensor: .device_lock,
            hkObjectType: nil,
            hkUnit: nil,
            unitString: "",
            logType: .device,
            biomarkerCategory: .device,
            statsOptions: .cumulativeSum
        )
    ]

    // MARK: Exercise
    private static let exerciseSensorMetadata: [SahhaSensor: SensorMetadata] = [
        .exercise: .init(
            sensor: .exercise,
            hkObjectType: HKWorkoutType.workoutType(),
            hkUnit: .minute(),
            unitString: "minute",
            logType: .exercise,
            biomarkerCategory: .exercise,
            statsOptions: .cumulativeSum
        )
    ]

    // MARK: Nutrition
    private static let nutritionSensorMetadata: [SahhaSensor: SensorMetadata] = [
        .energy_consumed: .init(
            sensor: .energy_consumed,
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed),
            hkUnit: .largeCalorie(),
            unitString: "kcal",
            logType: .nutrition,
            biomarkerCategory: .nutrition,
            statsOptions: .cumulativeSum
        )
    ]

    // MARK: Merged Metadata
    private static let mergedMetadata: [SahhaSensor: SensorMetadata] = {
        var merged: [SahhaSensor: SensorMetadata] = [:]
        merged.merge(demographicSensorMetaData) { _, new in new }
        merged.merge(sleepSensorMetaData) { _, new in new }
        merged.merge(activitySensorMetaData) { _, new in new }
        if #available(iOS 16.0, *) {
            merged.merge(iOS16ActivitySensorMetadata) { _, new in new }
        }
        merged.merge(heartSensorMetadata) { _, new in new }
        merged.merge(bloodSensorMetadata) { _, new in new }
        merged.merge(oxygenSensorMetaData) { _, new in new }
        merged.merge(energySensorMetadata) { _, new in new }
        if #available(iOS 17.0, *) {
            merged.merge(iOS17EnergySensorMetadata) { _, new in new }
        }
        merged.merge(temperatureSensorMetadata) { _, new in new }
        if #available(iOS 16.0, *) {
            merged.merge(iOS16TemperatureSensorMetadata) { _, new in new }
        }
        merged.merge(bodySensorMetadata) { _, new in new }
        merged.merge(deviceSensorMetadata) { _, new in new }
        merged.merge(exerciseSensorMetadata) { _, new in new }
        merged.merge(nutritionSensorMetadata) { _, new in new }
        return merged
    }()

    private static let reverseMetadata: [String: SensorMetadata] = {
        var reverse: [String: SensorMetadata] = [:]
        for meta in mergedMetadata.values {
            if let objectType = meta.hkObjectType {
                reverse[objectType.identifier] = meta
            }
        }
        return reverse
    }()

    // MARK: Helpers
    static func metadata(for sensor: SahhaSensor) -> SensorMetadata? {
        mergedMetadata[sensor]
    }

    static func metadata(for objectType: HKObjectType) -> SensorMetadata? {
        reverseMetadata[objectType.identifier]
    }
}
