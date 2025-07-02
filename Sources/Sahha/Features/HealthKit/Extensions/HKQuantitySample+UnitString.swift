import HealthKit

extension HKQuantitySample {
    private static let unitMappings: [String: String] = {
        var mappings: [String: String] = [
            // Activity
            HKQuantityTypeIdentifier.appleWalkingSteadiness.rawValue: "percent",
            HKQuantityTypeIdentifier.flightsClimbed.rawValue: "count",
            HKQuantityTypeIdentifier.sixMinuteWalkTestDistance.rawValue: "m",
            HKQuantityTypeIdentifier.stairAscentSpeed.rawValue: "m/s",
            HKQuantityTypeIdentifier.stairDescentSpeed.rawValue: "m/s",
            HKQuantityTypeIdentifier.stepCount.rawValue: "count",
            HKQuantityTypeIdentifier.walkingAsymmetryPercentage.rawValue: "percent",
            HKQuantityTypeIdentifier.walkingDoubleSupportPercentage.rawValue: "percent",
            HKQuantityTypeIdentifier.walkingSpeed.rawValue: "m/s",
            HKQuantityTypeIdentifier.walkingStepLength.rawValue: "m",
            HKQuantityTypeIdentifier.appleStandTime.rawValue: "minute",
            HKQuantityTypeIdentifier.appleMoveTime.rawValue: "minute",
            HKQuantityTypeIdentifier.appleExerciseTime.rawValue: "minute",
            // Blood
            HKQuantityTypeIdentifier.bloodGlucose.rawValue: "mg/dL",
            HKQuantityTypeIdentifier.bloodPressureDiastolic.rawValue: "mmHg",
            HKQuantityTypeIdentifier.bloodPressureSystolic.rawValue: "mmHg",
            // Body
            HKQuantityTypeIdentifier.bodyFatPercentage.rawValue: "percent",
            HKQuantityTypeIdentifier.bodyMassIndex.rawValue: "count",
            HKQuantityTypeIdentifier.bodyMass.rawValue: "kg",
            HKQuantityTypeIdentifier.height.rawValue: "m",
            HKQuantityTypeIdentifier.leanBodyMass.rawValue: "kg",
            HKQuantityTypeIdentifier.waistCircumference.rawValue: "m",
            // Energy
            HKQuantityTypeIdentifier.activeEnergyBurned.rawValue: "kcal",
            HKQuantityTypeIdentifier.basalEnergyBurned.rawValue: "kcal",
            // Heart
            HKQuantityTypeIdentifier.heartRate.rawValue: "bpm",
            HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue: "ms",
            HKQuantityTypeIdentifier.restingHeartRate.rawValue: "bpm",
            HKQuantityTypeIdentifier.walkingHeartRateAverage.rawValue: "bpm",
            // Nutrition
            HKQuantityTypeIdentifier.dietaryEnergyConsumed.rawValue: "kcal",
            // Oxygen
            HKQuantityTypeIdentifier.oxygenSaturation.rawValue: "percent",
            HKQuantityTypeIdentifier.respiratoryRate.rawValue: "bps",
            HKQuantityTypeIdentifier.vo2Max.rawValue: "ml/kg/min",
            // Temperature
            HKQuantityTypeIdentifier.basalBodyTemperature.rawValue: "degC",
            HKQuantityTypeIdentifier.bodyTemperature.rawValue: "degC",
        ]

        if #available(iOS 16.0, *) {
            let iOS16Mappings: [String: String] = [
                // Activity
                HKQuantityTypeIdentifier.runningStrideLength.rawValue: "m",
                HKQuantityTypeIdentifier.runningGroundContactTime.rawValue: "ms",
                HKQuantityTypeIdentifier.runningVerticalOscillation.rawValue: "cm",
                HKQuantityTypeIdentifier.runningPower.rawValue: "watt",
                HKQuantityTypeIdentifier.runningSpeed.rawValue: "m/s",
                // Temperature
                HKQuantityTypeIdentifier.appleSleepingWristTemperature.rawValue: "degC",
            ]
            mappings.merge(iOS16Mappings) { (_, new) in new }
        }

        if #available(iOS 17.0, *) {
            let iOS17Mappings: [String: String] = [
                // Energy
                HKQuantityTypeIdentifier.timeInDaylight.rawValue: "minute"
            ]
            mappings.merge(iOS17Mappings) { (_, new) in new }
        }

        return mappings
    }()
    
    var unitString: String {
        return Self.unitMappings[self.quantityType.identifier] ?? ""
    }
}
