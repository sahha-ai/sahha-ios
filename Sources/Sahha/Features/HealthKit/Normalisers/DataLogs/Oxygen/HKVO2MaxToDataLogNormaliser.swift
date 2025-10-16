import HealthKit

final class HKVO2MaxToDataLogNormaliser: HKSampleToDataLogNormaliserProtocol {
    func normalise(_ sample: HKSample) -> [DataLog] {
        guard let sample = sample as? HKQuantitySample,
            let sensor = sample.quantityType.sahhaSensor,
            sensor == .vo2_max,
            let unit = sensor.hkUnit
        else { return [] }

        var properties: [String: String] = [:]

        if let rawValue = sample.metadata?[HKMetadataKeyHeartRateSensorLocation] as? NSNumber,
            let value = HKVO2MaxTestType(rawValue: rawValue.intValue)
        {
            properties["measurement_method"] = value.stringValue
        }

        let additionalProperties: [String: String]? = properties.isEmpty ? nil : properties

        let value = sample.quantity.doubleValue(for: unit).rounded(toPlaces: 4)

        return [
            DataLog(
                logType: sensor.dataLogType,
                dataType: sensor.rawValue,
                value: value,
                unit: sensor.unitString,
                source: sample.sourceId,
                recordingMethod: sample.recordingMethod,
                deviceType: sample.deviceType,
                startDate: sample.startDate,
                endDate: sample.endDate,
                additionalProperties: additionalProperties
            )
        ]
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
