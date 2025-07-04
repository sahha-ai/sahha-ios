import HealthKit

struct HKWorkoutNormaliser: HKNormaliser {
    func normalise(sample: HKSample) -> [DataLog]? {
        guard let workoutSample = sample as? HKWorkout, let sensor = SahhaSensor.sensor(for: workoutSample.sampleType) else {
            return nil
        }
        
        let workoutLog = DataLog(
            parentId: nil,
            logType: sensor.logType,
            dataType: "exercise_session_\(workoutSample.workoutActivityType.name)",
            value: 1.0,
            unit: "minute",
            source: workoutSample.sourceId,
            recordingMethod: workoutSample.recordingMethod,
            deviceType: workoutSample.deviceType,
            startDate: workoutSample.startDate,
            endDate: workoutSample.endDate,
            additionalProperties: nil
        )
        
        var additionalProperties: [String: String] = [:]
        
        if let distance = workoutSample.totalDistance {
            let value = distance.doubleValue(for: .meter()).rounded(toPlaces: 4)
            additionalProperties["total_distance"] = "\(value)"
        }
        
        if let energy = workoutSample.totalEnergyBurned {
            let value = energy.doubleValue(for: .largeCalorie()).rounded(toPlaces: 4)
            additionalProperties["total_energy_burned"] = "\(value)"
        }
        
        if !additionalProperties.isEmpty {
            workoutLog.additionalProperties = additionalProperties
        }

        var logs: [DataLog] = [workoutLog]

        let parentId = workoutLog.id

        if let workoutEvents = workoutSample.workoutEvents, !workoutEvents.isEmpty {
            logs.append(
                contentsOf: workoutEvents.compactMap { event in
                    .init(
                        parentId: parentId,
                        logType: sensor.logType,
                        dataType: "exercise_event_\(event.type.name)",
                        value: 1.0,
                        unit: "minute",
                        source: workoutSample.sourceId,
                        recordingMethod: workoutSample.recordingMethod,
                        deviceType: workoutSample.deviceType,
                        startDate: event.dateInterval.start,
                        endDate: event.dateInterval.end,
                        additionalProperties: nil
                    )
                }
            )
        }

        if #available(iOS 16.0, *), !workoutSample.workoutActivities.isEmpty {
            let workoutActivities = workoutSample.workoutActivities
            logs.append(
                contentsOf: workoutActivities.compactMap { activity in
                    .init(
                        parentId: parentId,
                        logType: sensor.logType,
                        dataType: "exercise_segment_\(activity.workoutConfiguration.activityType.name)",
                        value: 1.0,
                        unit: "minute",
                        source: workoutSample.sourceId,
                        recordingMethod: workoutSample.recordingMethod,
                        deviceType: workoutSample.deviceType,
                        startDate: activity.startDate,
                        endDate: activity.endDate ?? activity.startDate + activity.duration,
                        additionalProperties: nil
                    )
                }
            )
        }

        return logs
    }
}

extension HKWorkoutEventType {
    fileprivate var name: String {
        switch self {
        case .pause: return "pause"
        case .resume: return "resume"
        case .lap: return "lap"
        case .marker: return "marker"
        case .motionPaused: return "motion_paused"
        case .motionResumed: return "motion_resumed"
        case .segment: return "segment"
        case .pauseOrResumeRequest: return "pause_or_resume_request"
        @unknown default: return "unknown"
        }
    }
}

extension HKWorkoutActivityType {
    fileprivate var name: String {
        switch self {
        case .americanFootball: return "american_football"
        case .archery: return "archery"
        case .australianFootball: return "australian_football"
        case .badminton: return "badminton"
        case .baseball: return "baseball"
        case .basketball: return "basketball"
        case .bowling: return "bowling"
        case .boxing: return "boxing"
        case .climbing: return "climbing"
        case .cricket: return "cricket"
        case .crossTraining: return "cross_training"
        case .curling: return "curling"
        case .cycling: return "cycling"
        case .dance: return "dance"
        case .danceInspiredTraining: return "dance_inspired_training"
        case .elliptical: return "elliptical"
        case .equestrianSports: return "equestrian_sports"
        case .fencing: return "fencing"
        case .fishing: return "fishing"
        case .functionalStrengthTraining: return "functional_strength_training"
        case .golf: return "golf"
        case .gymnastics: return "gymnastics"
        case .handball: return "handball"
        case .hiking: return "hiking"
        case .hockey: return "hockey"
        case .hunting: return "hunting"
        case .lacrosse: return "lacrosse"
        case .martialArts: return "martial_arts"
        case .mindAndBody: return "mind_and_body"
        case .mixedMetabolicCardioTraining: return "mixed_metabolic_cardio_training"
        case .paddleSports: return "paddle_sports"
        case .play: return "play"
        case .preparationAndRecovery: return "preparation_and_recovery"
        case .racquetball: return "racquetball"
        case .rowing: return "rowing"
        case .rugby: return "rugby"
        case .running: return "running"
        case .sailing: return "sailing"
        case .skatingSports: return "skating_sports"
        case .snowSports: return "snow_sports"
        case .soccer: return "soccer"
        case .softball: return "softball"
        case .squash: return "squash"
        case .stairClimbing: return "stair_climbing"
        case .surfingSports: return "surfing_sports"
        case .swimming: return "swimming"
        case .tableTennis: return "table_tennis"
        case .tennis: return "tennis"
        case .trackAndField: return "track_and_field"
        case .traditionalStrengthTraining: return "traditional_strength_training"
        case .volleyball: return "volleyball"
        case .walking: return "walking"
        case .waterFitness: return "water_fitness"
        case .waterPolo: return "water_polo"
        case .waterSports: return "water_sports"
        case .wrestling: return "wrestling"
        case .yoga: return "yoga"
        case .barre: return "barre"
        case .coreTraining: return "core_training"
        case .crossCountrySkiing: return "cross_country_skiing"
        case .downhillSkiing: return "downhill_skiing"
        case .flexibility: return "flexibility"
        case .highIntensityIntervalTraining: return "high_intensity_interval_training"
        case .jumpRope: return "jump_rope"
        case .kickboxing: return "kickboxing"
        case .pilates: return "pilates"
        case .snowboarding: return "snowboarding"
        case .stairs: return "stairs"
        case .stepTraining: return "step_training"
        case .wheelchairWalkPace: return "wheelchair_walk_pace"
        case .wheelchairRunPace: return "wheelchair_run_pace"
        case .taiChi: return "tai_chi"
        case .mixedCardio: return "mixed_cardio"
        case .handCycling: return "hand_cycling"
        case .discSports: return "disc_sports"
        case .fitnessGaming: return "fitness_gaming"
        case .cardioDance: return "cardio_dance"
        case .socialDance: return "social_dance"
        case .pickleball: return "pickleball"
        case .cooldown: return "cooldown"
        case .swimBikeRun: return "swim_bike_run"
        case .transition: return "transition"
        case .underwaterDiving: return "underwater_diving"
        case .other: return "other"
        @unknown default: return "unknown"
        }
    }
}
