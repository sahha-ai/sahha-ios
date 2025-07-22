import HealthKit

enum BloodGlucoseToDataLog {
    static func normalise(_ samples: [HKSample], sensor: SahhaSensor) -> [DataLog] {
        guard sensor == .blood_glucose else {
            return []
        }

        return samples.compactMap { sample in
            guard let quantitySample = sample as? HKQuantitySample,
                let unit = sensor.hkUnit
            else {
                return nil
            }

            var properties: [String: String] = [:]
            
            if let rawValue = quantitySample.metadata?[HKMetadataKeyBloodGlucoseMealTime] as? NSNumber,
               let value = HKBloodGlucoseMealTime(rawValue: rawValue.intValue) {
                properties["relation_to_meal"] = value.stringValue
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

extension HKBloodGlucoseMealTime {
    fileprivate var stringValue: String {
        switch self {
        case .preprandial: return "before_meal"
        case .postprandial: return "after_meal"
        @unknown default: return "unknown"
        }
    }
}
