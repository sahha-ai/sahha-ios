import HealthKit

extension HKSample {
    private static let objectTypeToBiomarkerCategory: [String: SahhaBiomarkerCategory] = {
        var mappings: [String: SahhaBiomarkerCategory] = [
            // Sleep
            HKCategoryTypeIdentifier.sleepAnalysis.rawValue: .sleep,
            // Activity
            HKQuantityTypeIdentifier.appleWalkingSteadiness.rawValue:  .activity,
            HKQuantityTypeIdentifier.flightsClimbed.rawValue: .activity,
            HKQuantityTypeIdentifier.sixMinuteWalkTestDistance.rawValue: .activity,
            HKQuantityTypeIdentifier.stairAscentSpeed.rawValue: .activity,
            HKQuantityTypeIdentifier.stairDescentSpeed.rawValue: .activity,
            HKQuantityTypeIdentifier.stepCount.rawValue: .activity,
            HKQuantityTypeIdentifier.walkingAsymmetryPercentage.rawValue: .activity,
            HKQuantityTypeIdentifier.walkingDoubleSupportPercentage.rawValue: .activity,
            HKQuantityTypeIdentifier.walkingSpeed.rawValue: .activity,
            HKQuantityTypeIdentifier.walkingStepLength.rawValue: .activity,
            HKQuantityTypeIdentifier.appleStandTime.rawValue: .activity,
            HKQuantityTypeIdentifier.appleMoveTime.rawValue: .activity,
            HKQuantityTypeIdentifier.appleExerciseTime.rawValue: .activity,
            HKQuantityTypeIdentifier.activeEnergyBurned.rawValue: .activity,
            HKQuantityTypeIdentifier.basalEnergyBurned.rawValue: .activity,
            // Vitals
            HKQuantityTypeIdentifier.bloodGlucose.rawValue: .vitals,
            HKQuantityTypeIdentifier.bloodPressureDiastolic.rawValue: .vitals,
            HKQuantityTypeIdentifier.bloodPressureSystolic.rawValue: .vitals,
            HKQuantityTypeIdentifier.oxygenSaturation.rawValue: .vitals,
            HKQuantityTypeIdentifier.respiratoryRate.rawValue: .vitals,
            HKQuantityTypeIdentifier.vo2Max.rawValue: .vitals,
            HKQuantityTypeIdentifier.heartRate.rawValue: .vitals,
            HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue: .vitals,
            HKQuantityTypeIdentifier.restingHeartRate.rawValue: .vitals,
            HKQuantityTypeIdentifier.walkingHeartRateAverage.rawValue: .vitals,
            HKQuantityTypeIdentifier.basalBodyTemperature.rawValue: .vitals,
            HKQuantityTypeIdentifier.bodyTemperature.rawValue: .vitals,
            // Body
            HKQuantityTypeIdentifier.bodyFatPercentage.rawValue: .body,
            HKQuantityTypeIdentifier.bodyMassIndex.rawValue: .body,
            HKQuantityTypeIdentifier.bodyMass.rawValue: .body,
            HKQuantityTypeIdentifier.height.rawValue: .body,
            HKQuantityTypeIdentifier.leanBodyMass.rawValue: .body,
            HKQuantityTypeIdentifier.waistCircumference.rawValue: .body,
            // Nutrition
            HKQuantityTypeIdentifier.dietaryEnergyConsumed.rawValue: .nutrition,
            // Exercise
            HKWorkoutTypeIdentifier: .exercise,
        ]

        if #available(iOS 16.0, *) {
            let iOS16Mappings: [String: SahhaBiomarkerCategory] = [
                // Activity
                HKQuantityTypeIdentifier.runningStrideLength.rawValue: .activity,
                HKQuantityTypeIdentifier.runningGroundContactTime.rawValue: .activity,
                HKQuantityTypeIdentifier.runningVerticalOscillation.rawValue: .activity,
                HKQuantityTypeIdentifier.runningPower.rawValue: .activity,
                HKQuantityTypeIdentifier.runningSpeed.rawValue:  .activity,
                // Vitals
                HKQuantityTypeIdentifier.appleSleepingWristTemperature.rawValue: .vitals,
            ]
            mappings.merge(iOS16Mappings) { (_, new) in new }
        }

        if #available(iOS 17.0, *) {
            let iOS17Mappings: [String: SahhaBiomarkerCategory] = [
                // Activity
                HKQuantityTypeIdentifier.timeInDaylight.rawValue: .activity
            ]
            mappings.merge(iOS17Mappings) { (_, new) in new }
        }

        return mappings
    }()
    
//    var biomarkerCategory: SahhaBiomarkerCategory {
//        return Self.objectTypeToBiomarkerCategory[self.sampleType.identifier]
//    }
}
