//import Foundation
//import HealthKit
//
//struct HealthKitSampleMapper {
//    func mapSamples(_ samples: [HKSample], for sensor: SahhaSensor) throws -> [SahhaSample] {
//        guard !samples.isEmpty else {
//            throw ValidationError.emptyCollection(collection: "HealthKit samples")
//        }
//
//        switch samples[0].logType {
//        case .sleep:
//            guard let categorySamples = samples as? [HKCategorySample] else {
//                throw HealthKitError.queryFailed(sensor: sensor.rawValue)
//            }
//            return try mapSleepSamples(categorySamples, for: sensor)
//        case .exercise:
//            guard let workoutSamples = samples as? [HKWorkout] else {
//                throw HealthKitError.queryFailed(sensor: sensor.rawValue)
//            }
//            return try mapExerciseSamples(workoutSamples, for: sensor)
//        default:
//            guard let quantitySamples = samples as? [HKQuantitySample] else {
//                throw HealthKitError.queryFailed(sensor: sensor.rawValue)
//            }
//            return try mapQuantitySamples(quantitySamples, for: sensor)
//        }
//    }
//
//    /// Maps HKQuantitySample to SahhaSample for quantity-based sensors.
//    private func mapQuantitySamples(_ samples: [HKQuantitySample], for sensor: SahhaSensor) throws -> [SahhaSample] {
//        try samples.map { sample in
//            let value: Double
//            if let unit = sample.unit {
//                value = sample.quantity.doubleValue(for: unit)
//            } else {
//                throw HealthKitError.unknownType
//            }
//            let recordingMethod = sample.recordingMethod.stringValue
//            return SahhaSample(
//                id: sample.uuid.uuidString,
//                category: sensor.category.rawValue,
//                type: sensor.rawValue,
//                value: value,
//                unit: sample.unitString,
//                startDateTime: sample.startDate,
//                endDateTime: sample.endDate,
//                recordingMethod: recordingMethod,
//                source: sample.sourceRevision.source.bundleIdentifier,
//                stats: []
//            )
//        }
//    }
//
//    /// Maps HKCategorySample to SahhaSample for sleep sensors.
//    private func mapSleepSamples(_ samples: [HKCategorySample], for sensor: SahhaSensor) throws -> [SahhaSample] {
//        try samples.map { sample in
//            guard let sleepValue = HKCategoryValueSleepAnalysis(rawValue: sample.value) else {
//                throw HealthKitError.unknownType
//            }
//            let sleepStage = mapSleepStage(sleepValue)
//            let difference = Calendar.current.dateComponents([.minute], from: sample.startDate, to: sample.endDate)
//            let value = Double(difference.minute ?? 0)
//            let recordingMethod = sample.recordingMethod.stringValue
//            return SahhaSample(
//                id: sample.uuid.uuidString,
//                category: sensor.category.rawValue,
//                type: sleepStage,
//                value: value,
//                unit: "minute",
//                startDateTime: sample.startDate,
//                endDateTime: sample.endDate,
//                recordingMethod: recordingMethod,
//                source: sample.sourceRevision.source.bundleIdentifier,
//                stats: []
//            )
//        }
//    }
//
//    /// Maps HKWorkout to SahhaSample for exercise sensors.
//    private func mapExerciseSamples(_ samples: [HKWorkout], for sensor: SahhaSensor) throws -> [SahhaSample] {
//        try samples.map { sample in
//            let difference = Calendar.current.dateComponents([.minute], from: sample.startDate, to: sample.endDate)
//            let value = Double(difference.minute ?? 0)
//            let recordingMethod = sample.recordingMethod.stringValue
//            var stats: [SahhaStat] = []
//            if #available(iOS 16.0, *) {
//                for (quantityType, stat) in sample.allStatistics {
//                    if let sensor = SahhaSensor(quantityType: quantityType),
//                       let sahhaStat = createSahhaStat(from: stat, quantityType: quantityType, sensor: sensor, periodicity: .daily) {
//                        stats.append(sahhaStat)
//                    }
//                }
//            }
//            return SahhaSample(
//                id: sample.uuid.uuidString,
//                category: sensor.category.rawValue,
//                type: "exercise_\(sample.workoutActivityType.name)",
//                value: value,
//                unit: sensor.unitString,
//                startDateTime: sample.startDate,
//                endDateTime: sample.endDate,
//                recordingMethod: recordingMethod,
//                source: sample.sourceRevision.source.bundleIdentifier,
//                stats: stats
//            )
//        }
//    }
//
//    /// Maps HKCategoryValueSleepAnalysis to SleepStage.
//    private func mapSleepStage(_ sleepValue: HKCategoryValueSleepAnalysis) -> String {
//        if #available(iOS 16.0, *) {
//            switch sleepValue {
//            case .inBed:
//                return "sleep_stage_in_bed"
//            case .awake:
//                return "sleep_stage_awake"
//            case .asleepREM:
//                return "sleep_stage_rem"
//            case .asleepCore:
//                return "sleep_stage_light"
//            case .asleepDeep:
//                return "sleep_stage_deep"
//            case .asleepUnspecified:
//                return "sleep_stage_sleeping"
//            default:
//                return "sleep_stage_unknown"
//            }
//        } else {
//            switch sleepValue {
//            case .inBed:
//                return "sleep_stage_in_bed"
//            case .awake:
//                return "sleep_stage_awake"
//            case .asleep:
//                return "sleep_stage_sleeping"
//            default:
//                return "sleep_stage_unknown"
//            }
//        }
//    }

    /// Creates a SahhaStat from an HKStatistics object.
//    private func createSahhaStat(from stat: HKStatistics, quantityType: HKQuantityType, sensor: SahhaSensor, periodicity: PeriodicityIdentifier) -> SahhaStat? {
//        var quantity: HKQuantity?
//        var aggregation: String?
//        
//        switch quantityType.aggregationStyle {
//        case .cumulative:
//            quantity = stat.sumQuantity()
//            aggregation = "sum"
//        case .discrete, .discreteArithmetic, .discreteTemporallyWeighted:
//            quantity = stat.averageQuantity()
//            aggregation = "avg"
//        default:
//            return nil
//        }
//        guard let quantity = quantity, let unit = stat.unit else {
//            return nil
//        }
//        let value = quantity.doubleValue(for: unit)
//        let sources = stat.sources?.map { $0.bundleIdentifier } ?? []
//        return SahhaStat(
//            id: UUID().uuidString,
//            category: sensor.category.rawValue,
//            type: sensor.rawValue,
//            aggregation: aggregation.rawValue,
//            periodicity: periodicity.rawValue,
//            value: value,
//            unit: sensor.unitString,
//            startDateTime: stat.startDate,
//            endDateTime: stat.endDate,
//            sources: sources
//        )
//    }
//}
