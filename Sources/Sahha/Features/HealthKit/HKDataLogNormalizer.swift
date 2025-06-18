//import HealthKit
//
//final class HKDataLogNormalizer: Normalizable {
//    typealias Input = HKSample
//    typealias Output = [DataLog]
//    
//    func normalize(_ input: HKSample) async -> [DataLog] {
//        let source = input.sourceRevision.source.name
//        let deviceType = input.sourceRevision.productType ?? "Unknown"
//        let startDate = input.startDate
//        let endDate = input.endDate
//        let recordingMethod = getRecordingMethod(input)
//        
//        switch input {
//        case let categorySample as HKCategorySample:
//            return []
//        case let quantitySample as HKQuantitySample:
//            return []
//        case let workout as HKWorkout:
//            return []
//        default:
//            print("Unsupported sample type: \(String(describing: type(of: input)))")
//            return []
//        }
//    }
//    
//    private func getRecordingMethod(_ sample: HKSample) -> DataLogRecordingMethod {
//        guard let value = sample.metadata?[HKMetadataKeyWasUserEntered] as? NSNumber else {
//            return .unknown
//        }
//        return value.boolValue ? .manual : .automatic
//    }
//    
//    private func normalizeQuantitySample(_ quantitySample: HKQuantitySample,source: String, deviceType: String, recordingMethod: DataLogRecordingMethod, startDate: Date, endDate: Date) -> [DataLog] {
//        guard let sensor = SahhaSensor.from(sampleType: quantitySample.quantityType),
//            let unit = sensor.hkUnit else { return [] }
//        
//        let value = quantitySample.quantity.doubleValue(for: unit).rounded(to: 4)
//        
//        return [DataLog(
//            parentId: nil,
//            dataType: sensor.rawValue,
//            value: value,
//            source: source,
//            recordingMethod: recordingMethod,
//            deviceType: deviceType,
//            startDate: startDate,
//            endDate: endDate,
//            additionalProperties: nil // TODO
//        )]
//    }
//    
//    private func normalizeCategorySample(_ categorySample: HKCategorySample,source: String, deviceType: String, recordingMethod: DataLogRecordingMethod, startDate: Date, endDate: Date) -> [DataLog] {
//        guard let sensor = SahhaSensor.from(sampleType: categorySample.categoryType) else { return [] }
//        
//        switch sensor {
//        case .sleep:
//            guard let sleepStage = HKCategoryValueSleepAnalysis(rawValue: categorySample.value) else { return [] }
//            let duration = Calendar.current.dateComponents([.minute], from: startDate, to: endDate).minute ?? 0
//            let value = Double(duration).rounded(to: 4)
//            
//            guard value > 0 else { return [] }
//            
//            return [DataLog(
//                dataType: "sleep_stage_" + sleepStage.name,
//                value: value,
//                source: source,
//                recordingMethod: recordingMethod,
//                deviceType: deviceType,
//                startDate: startDate,
//                endDate: endDate
//            )]
//        default:
//            return []
//        }
//    }
//    
//    private func normalizeWorkout(_ workout: HKWorkout,source: String, deviceType: String, recordingMethod: DataLogRecordingMethod, startDate: Date, endDate: Date) -> [DataLog] {
//        var logs: [DataLog] = []
//        
//        let workoutLog = DataLog(
//            dataType: "exercise_session_" + workout.workoutActivityType.name,
//            value: 1.0,
//            source: source,
//            recordingMethod: recordingMethod,
//            deviceType: deviceType,
//            startDate: startDate,
//            endDate: endDate,
//            additionalProperties: nil
//        )
//        
//        let parentId = workoutLog.id.uuidString
//        logs.append(workoutLog)
//        
//        if let workoutEvents = workout.workoutEvents {
//            logs.append(contentsOf: workoutEvents.compactMap { event in
//                DataLog(
//                    parentId: parentId,
//                    dataType: "exercise_event_" + event.description,
//                    value: 1.0,
//                    source: source,
//                    recordingMethod: recordingMethod,
//                    deviceType: deviceType,
//                    startDate: event.dateInterval.start,
//                    endDate: event.dateInterval.end
//                )
//            })
//        }
//        
//        if #available(iOS 16.0, *), !workout.workoutActivities.isEmpty {
//            logs.append(contentsOf: workout.workoutActivities.compactMap { activity in
//                DataLog(
//                    parentId: parentId,
//                    dataType: "exercise_segment_" + activity.workoutConfiguration.activityType.name,
//                    value: 1.0,
//                    source: source,
//                    recordingMethod: recordingMethod,
//                    deviceType: deviceType,
//                    startDate: activity.startDate,
//                    endDate: activity.endDate ?? activity.startDate + activity.duration
//                )
//            })
//        }
//        
//        return logs
//    }
//}
