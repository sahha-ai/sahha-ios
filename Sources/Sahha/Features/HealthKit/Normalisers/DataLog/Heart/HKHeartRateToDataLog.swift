import HealthKit

enum HKHeartRateToDataLog {
    static let normalise: Normaliser<HKSample, DataLog>.NormaliserFn = { sample in
        guard
            let sample = sample as? HKQuantitySample,
            let metadata = SensorMapper.metadata(for: sample.sampleType),
            [.heart_rate, .resting_heart_rate, .heart_rate_variability_sdnn, .walking_heart_rate_average].contains(metadata.sensor),
            let unit = metadata.hkUnit
        else {
            return []
        }
        
        var properties: [String: String] = [:]
        
        if let rawValue = sample.metadata?[HKMetadataKeyHeartRateSensorLocation] as? NSNumber,
           let value = HKHeartRateSensorLocation(rawValue: rawValue.intValue) {
            properties["sensor_location"] = value.stringValue
        }
        
        if let rawValue = sample.metadata?[HKMetadataKeyHeartRateMotionContext] as? NSNumber,
           let value = HKHeartRateMotionContext(rawValue: rawValue.intValue) {
            properties["motion_context"] = value.stringValue
        }
        
        let additionalProperties: [String: String]? = properties.isEmpty ? nil : properties

        return [
            DataLog(
                logType: metadata.logType,
                dataType: metadata.sensor.rawValue,
                value: sample.quantity.doubleValue(for: unit).rounded(toPlaces: 4),
                unit: metadata.unitString,
                source: sample.sourceId,
                recordingMethod: sample.recordingMethod,
                deviceType: sample.deviceType,
                startDate: sample.startDate,
                endDate: sample.endDate,
                additionalProperties: properties
            )
        ]
    }
}

extension HKHeartRateMotionContext {
    fileprivate var stringValue: String {
        switch self {
        case .notSet: return "not_set"
        case .sedentary: return "sedentary"
        case .active: return "active"
        @unknown default: return "unknown"
        }
    }
}

extension HKHeartRateSensorLocation {
    fileprivate var stringValue: String {
        switch self {
        case .chest: return "chest"
        case .earLobe: return "ear_lobe"
        case .finger: return "finger"
        case .foot: return "foot"
        case .hand: return "hand"
        case .wrist: return "wrist"
        case .other: return "other"
        @unknown default: return "unknown"
        }
    }
}


