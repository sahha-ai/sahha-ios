import HealthKit

enum VO2MaxToDataLog {
    static func normalise(_ samples: [HKSample], sensor: SahhaSensor) -> [DataLog] {
        guard sensor == .vo2_max else {
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
                let value = HKVO2MaxTestType(rawValue: rawValue.intValue)
            {
                properties["measurement_method"] = value.stringValue
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

extension HKVO2MaxTestType {
    fileprivate var stringValue: String {
        switch self {
        case .maxExercise: return "max_exercise"
        case .predictionNonExercise: return "prediction_non_exercise"
        case .predictionSubMaxExercise: return "prediction_sub_max_exercise"
        @unknown default: return "unknown"
        }
    }
}
