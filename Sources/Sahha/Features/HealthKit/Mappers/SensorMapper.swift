import HealthKit

struct SensorMapper {
    // Maps SahhaSensor to HKSampleType
    private static let sensorToSampleMap: [SahhaSensor: HKObjectType] = {
        var map: [SahhaSensor: HKObjectType] = [:]
        for sensor in SahhaSensor.allCases {
            if let sampleType = generateSampleType(for: sensor) {
                map[sensor] = sampleType
            }
        }
        return map
    }()

    // Maps HKSampleType.identifier to SahhaSensor
    private static let sampleToSensorMap: [String: SahhaSensor] = {
        var map: [String: SahhaSensor] = [:]
        for sensor in SahhaSensor.allCases {
            if let sampleType = generateSampleType(for: sensor) {
                map[sampleType.identifier] = sensor
            }
        }
        return map
    }()

    private static func generateSampleType(for sensor: SahhaSensor) -> HKObjectType? {
        switch sensor {
        case .steps:
            return HKQuantityType.quantityType(forIdentifier: .stepCount)
        case .floors_climbed:
            return HKQuantityType.quantityType(forIdentifier: .flightsClimbed)
        case .heart_rate:
            return HKQuantityType.quantityType(forIdentifier: .heartRate)
        case .resting_heart_rate:
            return HKQuantityType.quantityType(forIdentifier: .restingHeartRate)
        case .walking_heart_rate_average:
            return HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage)
        case .heart_rate_variability_sdnn:
            return HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
        case .blood_pressure_systolic:
            return HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)
        case .blood_pressure_diastolic:
            return HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)
        case .blood_glucose:
            return HKQuantityType.quantityType(forIdentifier: .bloodGlucose)
        case .vo2_max:
            return HKQuantityType.quantityType(forIdentifier: .vo2Max)
        case .oxygen_saturation:
            return HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)
        case .respiratory_rate:
            return HKQuantityType.quantityType(forIdentifier: .respiratoryRate)
        case .active_energy_burned:
            return HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        case .basal_energy_burned:
            return HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)
        case .body_temperature:
            return HKQuantityType.quantityType(forIdentifier: .bodyTemperature)
        case .basal_body_temperature:
            return HKQuantityType.quantityType(forIdentifier: .basalBodyTemperature)
        case .height:
            return HKQuantityType.quantityType(forIdentifier: .height)
        case .weight:
            return HKQuantityType.quantityType(forIdentifier: .bodyMass)
        case .lean_body_mass:
            return HKQuantityType.quantityType(forIdentifier: .leanBodyMass)
        case .body_mass_index:
            return HKQuantityType.quantityType(forIdentifier: .bodyMassIndex)
        case .body_fat:
            return HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)
        case .waist_circumference:
            return HKQuantityType.quantityType(forIdentifier: .waistCircumference)
        case .stand_time:
            return HKQuantityType.quantityType(forIdentifier: .appleStandTime)
        case .exercise_time:
            return HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)
        case .energy_consumed:
            return HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)
        case .move_time:
            if #available(iOS 14.5, *) {
                return HKQuantityType.quantityType(forIdentifier: .appleMoveTime)
            } else {
                return nil
            }
        case .walking_steadiness:
            if #available(iOS 15.0, *) {
                return HKQuantityType.quantityType(forIdentifier: .appleWalkingSteadiness)
            } else {
                return nil
            }
        case .sleeping_wrist_temperature:
            if #available(iOS 16.0, *) {
                return HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature)
            } else {
                return nil
            }
        case .time_in_daylight:
            if #available(iOS 17.0, *) {
                return HKQuantityType.quantityType(forIdentifier: .timeInDaylight)
            } else {
                return nil
            }
        case .running_speed:
            if #available(iOS 16.0, *) {
                return HKQuantityType.quantityType(forIdentifier: .runningSpeed)
            } else {
                return nil
            }
        case .running_power:
            if #available(iOS 16.0, *) {
                return HKQuantityType.quantityType(forIdentifier: .runningPower)
            } else {
                return nil
            }
        case .running_ground_contact_time:
            if #available(iOS 16.0, *) {
                return HKQuantityType.quantityType(forIdentifier: .runningGroundContactTime)
            } else {
                return nil
            }
        case .running_stride_length:
            if #available(iOS 16.0, *) {
                return HKQuantityType.quantityType(forIdentifier: .runningStrideLength)
            } else {
                return nil
            }
        case .running_vertical_oscillation:
            if #available(iOS 16.0, *) {
                return HKQuantityType.quantityType(forIdentifier: .runningVerticalOscillation)
            } else {
                return nil
            }
        case .six_minute_walk_test_distance:
            if #available(iOS 14.0, *) {
                return HKQuantityType.quantityType(forIdentifier: .sixMinuteWalkTestDistance)
            } else {
                return nil
            }
        case .stair_ascent_speed:
            if #available(iOS 14.0, *) {
                return HKQuantityType.quantityType(forIdentifier: .stairAscentSpeed)
            } else {
                return nil
            }
        case .stair_descent_speed:
            if #available(iOS 14.0, *) {
                return HKQuantityType.quantityType(forIdentifier: .stairDescentSpeed)
            } else {
                return nil
            }
        case .walking_speed:
            if #available(iOS 14.0, *) {
                return HKQuantityType.quantityType(forIdentifier: .walkingSpeed)
            } else {
                return nil
            }
        case .walking_asymmetry_percentage:
            if #available(iOS 14.0, *) {
                return HKQuantityType.quantityType(forIdentifier: .walkingAsymmetryPercentage)
            } else {
                return nil
            }
        case .walking_double_support_percentage:
            if #available(iOS 14.0, *) {
                return HKQuantityType.quantityType(forIdentifier: .walkingDoubleSupportPercentage)
            } else {
                return nil
            }
        case .walking_step_length:
            if #available(iOS 14.0, *) {
                return HKQuantityType.quantityType(forIdentifier: .walkingStepLength)
            } else {
                return nil
            }
        case .sleep:
            return HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)
        case .exercise:
            return HKWorkoutType.workoutType()
        case .gender:
            return HKCharacteristicType.characteristicType(forIdentifier: .biologicalSex)
        case .date_of_birth:
            return HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth)
        case .activity_summary:
            return HKSampleType.activitySummaryType()
        case .device_lock, .heart_rate_variability_rmssd, .total_energy_burned,
            .basal_metabolic_rate, .body_water_mass, .bone_mass:
            return nil
        @unknown default:
            return nil
        }
    }

    static func objectType(for sensor: SahhaSensor) -> HKObjectType? {
        return sensorToSampleMap[sensor]
    }

    static func sensor(for objectType: HKObjectType) -> SahhaSensor? {
        return sampleToSensorMap[objectType.identifier]
    }
}
