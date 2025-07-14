import HealthKit

enum HKBloodGlucoseToDataLog {
    static let normalise: Normaliser<HKSample, DataLog>.NormaliserFn = { sample in
        guard
            let sample = sample as? HKQuantitySample,
            let metadata = SensorMapper.metadata(for: sample.sampleType),
            metadata.sensor == .blood_glucose,
            let unit = metadata.hkUnit
        else {
            return []
        }
        
        var properties: [String: String] = [:]
        
        if let rawValue = sample.metadata?[HKMetadataKeyBloodGlucoseMealTime] as? NSNumber,
           let value = HKBloodGlucoseMealTime(rawValue: rawValue.intValue) {
            properties["relation_to_meal"] = value.stringValue
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

extension HKBloodGlucoseMealTime {
    fileprivate var stringValue: String {
        switch self {
        case .preprandial: return "before_meal"
        case .postprandial: return "after_meal"
        @unknown default: return "unknown"
        }
    }
}
