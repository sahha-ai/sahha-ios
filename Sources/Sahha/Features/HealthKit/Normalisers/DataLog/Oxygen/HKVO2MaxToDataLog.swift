import HealthKit

enum HKVO2MaxToDataLog {
    static let normalise: Normaliser<HKSample, DataLog>.NormaliserFn = { sample in
        guard
            let sample = sample as? HKQuantitySample,
            let metadata = SensorMapper.metadata(for: sample.sampleType),
            metadata.sensor == .vo2_max,
            let unit = metadata.hkUnit
        else {
            return []
        }
        
        var properties: [String: String] = [:]
        
        if let rawValue = sample.metadata?[HKMetadataKeyHeartRateSensorLocation] as? NSNumber,
           let value = HKVO2MaxTestType(rawValue: rawValue.intValue) {
            properties["measurement_method"] = value.stringValue
        }
        
        let additionalProperties: [String: String]? = properties.isEmpty ? nil : properties
        
        return [DataLog(
            logType: metadata.logType,
            dataType: metadata.sensor.rawValue,
            value: sample.quantity.doubleValue(for: unit).rounded(toPlaces: 4),
            unit: metadata.unitString,
            source: sample.sourceId,
            recordingMethod: sample.recordingMethod,
            deviceType: sample.deviceType,
            startDate: sample.startDate,
            endDate: sample.endDate,
            additionalProperties: additionalProperties
        )]
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
