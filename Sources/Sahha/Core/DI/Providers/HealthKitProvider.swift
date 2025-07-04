import HealthKit

struct HealthKitProvider: ServiceProvider {
    func registerServices(in container: DIContainer) async {
        await container.registerSingleton(HealthKitManagerProtocol.self) { container in
            let logger = try await container.resolve(LoggerProtocol.self)

            let processor = try await container.resolve(DataLogProcessorProtocol.self)
            let normalisers = createNormalisers()
            let anchorQueryHandler = AnchorQueryHandler(logger: logger, normalisers: normalisers, processor: processor)

            let observerQueryHandler = ObserverQueryHandler(logger: logger, anchorQueryHandler: anchorQueryHandler)
            let sampleQueryHandler = SampleQueryHandler(logger: logger)
            let statisticsQueryHandler = StatisticsQueryHandler(logger: logger)

            return HealthKitManager(
                logger: logger,
                observerQueryHandler: observerQueryHandler,
                sampleQueryHandler: sampleQueryHandler,
                statisticsQueryHandler: statisticsQueryHandler
            )
        }
    }

    private func createNormalisers() -> [String: any HKNormaliser] {
        var normalisers: [String: any HKNormaliser] = [
            // Activity
            HKQuantityTypeIdentifier.appleWalkingSteadiness.rawValue: HKAppleWalkingSteadinessNormaliser(),
            HKQuantityTypeIdentifier.flightsClimbed.rawValue: HKFlightsClimbedNormaliser(),
            HKQuantityTypeIdentifier.sixMinuteWalkTestDistance.rawValue: HKSixMinuteWalkTestDistanceNormaliser(),
            HKQuantityTypeIdentifier.stairAscentSpeed.rawValue: HKStairAscentSpeedNormaliser(),
            HKQuantityTypeIdentifier.stairDescentSpeed.rawValue: HKStairDescentSpeedNormaliser(),
            HKQuantityTypeIdentifier.stepCount.rawValue: HKStepCountNormaliser(),
            HKQuantityTypeIdentifier.walkingAsymmetryPercentage.rawValue: HKWalkingAsymmetryPercentageNormaliser(),
            HKQuantityTypeIdentifier.walkingDoubleSupportPercentage.rawValue: HKWalkingDoubleSupportPercentageNormaliser(),
            HKQuantityTypeIdentifier.walkingSpeed.rawValue: HKWalkingSpeedNormaliser(),
            HKQuantityTypeIdentifier.walkingStepLength.rawValue: HKWalkingStepLengthNormaliser(),
            HKQuantityTypeIdentifier.appleStandTime.rawValue: HKAppleStandTimeNormaliser(),
            HKQuantityTypeIdentifier.appleMoveTime.rawValue: HKAppleMoveTimeNormaliser(),
            HKQuantityTypeIdentifier.appleExerciseTime.rawValue: HKAppleExerciseTimeNormaliser(),
            // Blood
            HKQuantityTypeIdentifier.bloodGlucose.rawValue: HKBloodGlucoseNormaliser(),
            HKQuantityTypeIdentifier.bloodPressureDiastolic.rawValue: HKBloodPressureDiastolicNormaliser(),
            HKQuantityTypeIdentifier.bloodPressureSystolic.rawValue: HKBloodPressureSystolicNormaliser(),
            // Body
            HKQuantityTypeIdentifier.bodyFatPercentage.rawValue: HKBodyFatPercentageNormaliser(),
            HKQuantityTypeIdentifier.bodyMassIndex.rawValue: HKBodyMassIndexNormaliser(),
            HKQuantityTypeIdentifier.bodyMass.rawValue: HKBodyMassNormaliser(),
            HKQuantityTypeIdentifier.height.rawValue: HKHeightNormaliser(),
            HKQuantityTypeIdentifier.leanBodyMass.rawValue: HKLeanBodyMassNormaliser(),
            HKQuantityTypeIdentifier.waistCircumference.rawValue: HKWaistCircumferenceNormaliser(),
            // Energy
            HKQuantityTypeIdentifier.activeEnergyBurned.rawValue: HKActiveEnergyBurnedNormaliser(),
            HKQuantityTypeIdentifier.basalEnergyBurned.rawValue: HKBasalEnergyBurnedNormaliser(),
            // Heart
            HKQuantityTypeIdentifier.heartRate.rawValue: HKHeartRateNormaliser(),
            HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue: HKHeartRateVariabilitySDNNNormaliser(),
            HKQuantityTypeIdentifier.restingHeartRate.rawValue: HKRestingHeartRateNormaliser(),
            HKQuantityTypeIdentifier.walkingHeartRateAverage.rawValue: HKWalkingHeartRateAverageNormaliser(),
            // Nutrition
            HKQuantityTypeIdentifier.dietaryEnergyConsumed.rawValue: HKDietaryEnergyConsumedNormaliser(),
            // Oxygen
            HKQuantityTypeIdentifier.oxygenSaturation.rawValue: HKOxygenSaturationNormaliser(),
            HKQuantityTypeIdentifier.respiratoryRate.rawValue: HKRespiratoryRateNormaliser(),
            HKQuantityTypeIdentifier.vo2Max.rawValue: HKVO2MaxNormaliser(),
            // Temperature
            HKQuantityTypeIdentifier.basalBodyTemperature.rawValue: HKBasalBodyTemperatureNormaliser(),
            HKQuantityTypeIdentifier.bodyTemperature.rawValue: HKBodyTemperatureNormaliser(),
            // Sleep
            HKCategoryTypeIdentifier.sleepAnalysis.rawValue: HKSleepAnalysisNormaliser(),
            // Workout
            HKWorkoutTypeIdentifier: HKWorkoutNormaliser(),
        ]

        if #available(iOS 16.0, *) {
            let iOS16Normalisers: [String: any HKNormaliser] = [
                // Activity
                HKQuantityTypeIdentifier.runningStrideLength.rawValue: HKRunningStrideLengthNormaliser(),
                HKQuantityTypeIdentifier.runningGroundContactTime.rawValue: HKRunningGroundContactTimeNormaliser(),
                HKQuantityTypeIdentifier.runningVerticalOscillation.rawValue: HKRunningVerticalOscillationNormaliser(),
                HKQuantityTypeIdentifier.runningPower.rawValue: HKRunningPowerNormaliser(),
                HKQuantityTypeIdentifier.runningSpeed.rawValue: HKRunningSpeedNormaliser(),
                // Temperature
                HKQuantityTypeIdentifier.appleSleepingWristTemperature.rawValue: HKAppleSleepingWristTemperatureNormaliser(),
            ]
            normalisers.merge(iOS16Normalisers) { (_, new) in new }
        }

        if #available(iOS 17.0, *) {
            let iOS17Normalisers: [String: any HKNormaliser] = [
                // Energy
                HKQuantityTypeIdentifier.timeInDaylight.rawValue: HKTimeInDaylightNormaliser()
            ]
            normalisers.merge(iOS17Normalisers) { (_, new) in new }
        }

        return normalisers
    }
}
