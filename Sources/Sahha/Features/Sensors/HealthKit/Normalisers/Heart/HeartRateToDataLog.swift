import HealthKit

struct HeartRateToDataLog {
    private static let heartRateSensors: Set<SahhaSensor> = [
        .heart_rate,
        .resting_heart_rate,
        .heart_rate_variability_sdnn,
        .walking_heart_rate_average,
    ]

    static func normalise(_ samples: [HKSample], sensor: SahhaSensor) -> [DataLog] {
        guard heartRateSensors.contains(sensor) else {
            return []
        }

        return samples.compactMap { sample in
            guard let quantitySample = sample as? HKQuantitySample,
                let unit = sensor.hkUnit
            else {
                return nil
            }
            
            var properties: [String: String] = [:]
            
            if let rawValue = quantitySample.metadata?[HKMetadataKeyHeartRateSensorLocation] as? NSNumber,
               let value = HKHeartRateSensorLocation(rawValue: rawValue.intValue) {
                properties["sensor_location"] = value.stringValue
            }
            
            if let rawValue = quantitySample.metadata?[HKMetadataKeyHeartRateMotionContext] as? NSNumber,
               let value = HKHeartRateMotionContext(rawValue: rawValue.intValue) {
                properties["motion_context"] = value.stringValue
            }
            
            let additionalProperties: [String: String]? = properties.isEmpty ? nil : properties

            return DataLog(
                logType: sensor.logType,
                dataType: sensor.rawValue,
                value: quantitySample.quantity.doubleValue(for: unit).rounded(toPlaces: 4),
                unit: sensor.unitString,
                source: quantitySample.sourceId,
                recordingMethod: quantitySample.recordingMethod,
                deviceType: quantitySample.deviceType,
                startDate: quantitySample.startDate,
                endDate: quantitySample.endDate,
                additionalProperties: additionalProperties
            )
        }
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
