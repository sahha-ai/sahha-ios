import HealthKit

extension HKQuantitySample {
    private static let unitMappings: [String: HKUnit] = {
        var mappings: [String: HKUnit] = [
            // Activity
            HKQuantityTypeIdentifier.appleWalkingSteadiness.rawValue: .percent(),
            HKQuantityTypeIdentifier.flightsClimbed.rawValue: .count(),
            HKQuantityTypeIdentifier.sixMinuteWalkTestDistance.rawValue: .meter(),
            HKQuantityTypeIdentifier.stairAscentSpeed.rawValue: .meter().unitDivided(by: .second()),
            HKQuantityTypeIdentifier.stairDescentSpeed.rawValue: .meter().unitDivided(by: .second()),
            HKQuantityTypeIdentifier.stepCount.rawValue: .count(),
            HKQuantityTypeIdentifier.walkingAsymmetryPercentage.rawValue: .percent(),
            HKQuantityTypeIdentifier.walkingDoubleSupportPercentage.rawValue: .percent(),
            HKQuantityTypeIdentifier.walkingSpeed.rawValue: .meter().unitDivided(by: .second()),
            HKQuantityTypeIdentifier.walkingStepLength.rawValue: .meter(),
            HKQuantityTypeIdentifier.appleStandTime.rawValue: .minute(),
            HKQuantityTypeIdentifier.appleMoveTime.rawValue: .minute(),
            HKQuantityTypeIdentifier.appleExerciseTime.rawValue: .minute(),
            // Blood
            HKQuantityTypeIdentifier.bloodGlucose.rawValue: HKUnit(from: "mg/dL"),
            HKQuantityTypeIdentifier.bloodPressureDiastolic.rawValue: .millimeterOfMercury(),
            HKQuantityTypeIdentifier.bloodPressureSystolic.rawValue: .millimeterOfMercury(),
            // Body
            HKQuantityTypeIdentifier.bodyFatPercentage.rawValue: .percent(),
            HKQuantityTypeIdentifier.bodyMassIndex.rawValue: .count(),
            HKQuantityTypeIdentifier.bodyMass.rawValue: .gramUnit(with: .kilo),
            HKQuantityTypeIdentifier.height.rawValue: .meter(),
            HKQuantityTypeIdentifier.leanBodyMass.rawValue: .gramUnit(with: .kilo),
            HKQuantityTypeIdentifier.waistCircumference.rawValue: .meter(),
            // Energy
            HKQuantityTypeIdentifier.activeEnergyBurned.rawValue: .largeCalorie(),
            HKQuantityTypeIdentifier.basalEnergyBurned.rawValue: .largeCalorie(),
            // Heart
            HKQuantityTypeIdentifier.heartRate.rawValue: .count().unitDivided(by: .minute()),
            HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue: .secondUnit(with: .milli),
            HKQuantityTypeIdentifier.restingHeartRate.rawValue: .count().unitDivided(by: .minute()),
            HKQuantityTypeIdentifier.walkingHeartRateAverage.rawValue: .count().unitDivided(by: .minute()),
            // Nutrition
            HKQuantityTypeIdentifier.dietaryEnergyConsumed.rawValue: .largeCalorie(),
            // Oxygen
            HKQuantityTypeIdentifier.oxygenSaturation.rawValue: .percent(),
            HKQuantityTypeIdentifier.respiratoryRate.rawValue: .count().unitDivided(by: .second()),
            HKQuantityTypeIdentifier.vo2Max.rawValue: HKUnit(from: "ml/kg*min"),
            // Temperature
            HKQuantityTypeIdentifier.basalBodyTemperature.rawValue: .degreeCelsius(),
            HKQuantityTypeIdentifier.bodyTemperature.rawValue: .degreeCelsius(),
        ]

        if #available(iOS 16.0, *) {
            let iOS16Mappings: [String: HKUnit] = [
                // Activity
                HKQuantityTypeIdentifier.runningStrideLength.rawValue: .meter(),
                HKQuantityTypeIdentifier.runningGroundContactTime.rawValue: .secondUnit(with: .milli),
                HKQuantityTypeIdentifier.runningVerticalOscillation.rawValue: .meterUnit(with: .centi),
                HKQuantityTypeIdentifier.runningPower.rawValue: .watt(),
                HKQuantityTypeIdentifier.runningSpeed.rawValue: .meter().unitDivided(by: .second()),
                // Temperature
                HKQuantityTypeIdentifier.appleSleepingWristTemperature.rawValue: .degreeCelsius(),
            ]
            mappings.merge(iOS16Mappings) { (_, new) in new }
        }

        if #available(iOS 17.0, *) {
            let iOS17Mappings: [String: HKUnit] = [
                // Energy
                HKQuantityTypeIdentifier.timeInDaylight.rawValue: .minute()
            ]
            mappings.merge(iOS17Mappings) { (_, new) in new }
        }

        return mappings
    }()
    
    var unit: HKUnit? {
        return Self.unitMappings[self.quantityType.identifier]
    }
}
