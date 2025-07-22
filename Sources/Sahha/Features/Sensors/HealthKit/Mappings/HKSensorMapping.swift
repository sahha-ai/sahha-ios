import HealthKit

struct HKSensorMapping {
    struct Metadata {
        let hkObjectType: HKObjectType
        var hkUnit: HKUnit? = nil
        var statsOptions: HKStatisticsOptions = .cumulativeSum
        var additionalPermissions: Set<HKObjectType> = []
    }

    // MARK: Demographic
    private static let demographicMeta: [SahhaSensor: Metadata] = [
        .gender: .init(
            hkObjectType: HKCharacteristicType.characteristicType(forIdentifier: .biologicalSex)!
        ),
        .date_of_birth: .init(
            hkObjectType: HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth)!
        ),
    ]

    // MARK: Sleep
    private static let sleepMeta: [SahhaSensor: Metadata] = [
        .sleep: .init(
            hkObjectType: HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
            hkUnit: .minute(),
        )
    ]

    // MARK: Activity
    private static let activityMeta: [SahhaSensor: Metadata] = [
        .steps: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            hkUnit: .count(),
        ),
        .floors_climbed: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .flightsClimbed)!,
            hkUnit: .count(),
        ),
        .move_time: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .appleMoveTime)!,
            hkUnit: .minute(),
        ),
        .stand_time: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .appleStandTime)!,
            hkUnit: .minute(),
        ),
        .exercise_time: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!,
            hkUnit: .minute(),
        ),
        .activity_summary: .init(
            hkObjectType: HKSampleType.activitySummaryType(),
            hkUnit: .count(),
        ),
        .walking_asymmetry_percentage: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .walkingAsymmetryPercentage)!,
            hkUnit: .percent(),
            statsOptions: .discreteAverage
        ),
        .walking_speed: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .walkingSpeed)!,
            hkUnit: .meter().unitDivided(by: .second()),
            statsOptions: .discreteAverage
        ),
        .walking_steadiness: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .appleWalkingSteadiness)!,
            hkUnit: .percent(),
            statsOptions: .discreteAverage
        ),
        .walking_double_support_percentage: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .walkingDoubleSupportPercentage)!,
            hkUnit: .percent(),
            statsOptions: .discreteAverage
        ),
        .walking_step_length: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .walkingStepLength)!,
            hkUnit: .meter(),
            statsOptions: .discreteAverage
        ),
        .six_minute_walk_test_distance: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .sixMinuteWalkTestDistance)!,
            hkUnit: .meter(),
            statsOptions: .discreteAverage
        ),
        .stair_ascent_speed: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .stairAscentSpeed)!,
            hkUnit: .meter().unitDivided(by: .second()),
            statsOptions: .discreteAverage
        ),
        .stair_descent_speed: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .stairDescentSpeed)!,
            hkUnit: .meter().unitDivided(by: .second()),
            statsOptions: .discreteAverage
        ),
    ]

    // MARK: Activity (iOS 16)
    @available(iOS 16.0, *)
    private static let iOS16ActivityMeta: [SahhaSensor: Metadata] = [
        .running_speed: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .runningSpeed)!,
            hkUnit: .meter().unitDivided(by: .second()),
            statsOptions: .discreteAverage
        ),
        .running_power: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .runningPower)!,
            hkUnit: .watt(),
            statsOptions: .discreteAverage
        ),
        .running_ground_contact_time: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .runningGroundContactTime)!,
            hkUnit: .secondUnit(with: .milli),
            statsOptions: .discreteAverage
        ),
        .running_stride_length: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .runningStrideLength)!,
            hkUnit: .meter(),
            statsOptions: .discreteAverage
        ),
        .running_vertical_oscillation: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .runningVerticalOscillation)!,
            hkUnit: .meterUnit(with: .centi),
            statsOptions: .discreteAverage
        ),
    ]

    // MARK: Heart
    private static let heartMeta: [SahhaSensor: Metadata] = [
        .heart_rate: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            hkUnit: .count().unitDivided(by: .minute()),
            statsOptions: .discreteAverage
        ),
        .resting_heart_rate: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!,
            hkUnit: .count().unitDivided(by: .minute()),
            statsOptions: .discreteAverage
        ),
        .walking_heart_rate_average: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage)!,
            hkUnit: .count().unitDivided(by: .minute()),
            statsOptions: .discreteAverage
        ),
        .heart_rate_variability_sdnn: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            hkUnit: .secondUnit(with: .milli),
            statsOptions: .discreteAverage
        ),
    ]

    // MARK: Blood
    private static let bloodMeta: [SahhaSensor: Metadata] = [
        .blood_pressure_systolic: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)!,
            hkUnit: .millimeterOfMercury(),
            statsOptions: .discreteAverage,
            additionalPermissions: [HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)!]
        ),
        .blood_pressure_diastolic: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
            hkUnit: .millimeterOfMercury(),
            statsOptions: .discreteAverage,
            additionalPermissions: [HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)!]
        ),
        .blood_glucose: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!,
            hkUnit: HKUnit(from: "mg/dL"),
            statsOptions: .discreteAverage
        ),
    ]

    // MARK: Oxygen
    private static let oxygenMeta: [SahhaSensor: Metadata] = [
        .vo2_max: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .vo2Max)!,
            hkUnit: HKUnit(from: "ml/kg*min"),
            statsOptions: .discreteAverage
        ),
        .oxygen_saturation: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!,
            hkUnit: .percent(),
            statsOptions: .discreteAverage
        ),
        .respiratory_rate: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!,
            hkUnit: .count().unitDivided(by: .second()),
            statsOptions: .discreteAverage
        ),
    ]

    // MARK: Energy
    private static let energyMeta: [SahhaSensor: Metadata] = [
        .active_energy_burned: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            hkUnit: .largeCalorie(),
        ),
        .basal_energy_burned: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!,
            hkUnit: .largeCalorie(),
        ),
    ]

    // MARK: Energy (iOS 17)
    @available(iOS 17.0, *)
    private static let iOS17EnergyMeta: [SahhaSensor: Metadata] = [
        .time_in_daylight: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .timeInDaylight)!,
            hkUnit: .minute(),
        )
    ]

    // MARK: Temperature
    private static let temperatureMeta: [SahhaSensor: Metadata] = [
        .body_temperature: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!,
            hkUnit: .degreeCelsius(),
            statsOptions: .discreteAverage
        ),
        .basal_body_temperature: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .basalBodyTemperature)!,
            hkUnit: .degreeCelsius(),
            statsOptions: .discreteAverage
        ),

    ]

    // MARK: Temperature (iOS 16)
    @available(iOS 16.0, *)
    private static let iOS16TemperatureMeta: [SahhaSensor: Metadata] = [
        .sleeping_wrist_temperature: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature)!,
            hkUnit: .degreeCelsius(),
            statsOptions: .discreteAverage
        )
    ]

    // MARK: Body
    private static let bodyMeta: [SahhaSensor: Metadata] = [
        .height: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .height)!,
            hkUnit: .meter(),
            statsOptions: .discreteAverage
        ),
        .weight: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
            hkUnit: .gramUnit(with: .kilo),
            statsOptions: .discreteAverage
        ),
        .lean_body_mass: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .leanBodyMass)!,
            hkUnit: .gramUnit(with: .kilo),
            statsOptions: .discreteAverage
        ),
        .body_mass_index: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .bodyMassIndex)!,
            hkUnit: .count(),
            statsOptions: .discreteAverage
        ),
        .body_fat: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!,
            hkUnit: .percent(),
            statsOptions: .discreteAverage
        ),
        .waist_circumference: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .waistCircumference)!,
            hkUnit: .meter(),
            statsOptions: .discreteAverage
        ),
    ]

    // MARK: Exercise
    private static let exerciseMeta: [SahhaSensor: Metadata] = [
        .exercise: .init(
            hkObjectType: HKWorkoutType.workoutType(),
            hkUnit: .minute(),
        )
    ]

    // MARK: Nutrition
    private static let nutritionMeta: [SahhaSensor: Metadata] = [
        .energy_consumed: .init(
            hkObjectType: HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
            hkUnit: .largeCalorie(),
        )
    ]

    static let forward: [SahhaSensor: Metadata] = {
        var map: [SahhaSensor: Metadata] = [:]

        map.merge(demographicMeta) { _, new in new }
        map.merge(sleepMeta) { _, new in new }
        map.merge(activityMeta) { _, new in new }
        map.merge(heartMeta) { _, new in new }
        map.merge(bloodMeta) { _, new in new }
        map.merge(oxygenMeta) { _, new in new }
        map.merge(energyMeta) { _, new in new }
        map.merge(temperatureMeta) { _, new in new }
        map.merge(bodyMeta) { _, new in new }
        map.merge(exerciseMeta) { _, new in new }
        map.merge(nutritionMeta) { _, new in new }

        if #available(iOS 16.0, *) {
            map.merge(iOS16ActivityMeta) { _, new in new }
            map.merge(iOS16TemperatureMeta) { _, new in new }
        }

        if #available(iOS 17.0, *) {
            map.merge(iOS17EnergyMeta) { _, new in new }
        }

        return map
    }()

    static let reverse: [HKObjectType: SahhaSensor] = {
        var map = [HKObjectType: SahhaSensor]()
        for (sensor, meta) in forward {
            map[meta.hkObjectType] = sensor
            meta.additionalPermissions.forEach { map[$0] = sensor }
        }
        return map
    }()
}
