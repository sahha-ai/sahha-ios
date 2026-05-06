import HealthKit

final class HKBloodGlucoseToDataLogNormaliser: HKSampleToDataLogNormaliserProtocol {
    func normalise(_ sample: HKSample, profileId: String?) -> [DataLog] {
        guard let sample = sample as? HKQuantitySample,
            let sensor = sample.quantityType.sahhaSensor,
            sensor == .blood_glucose,
            let unit = sensor.hkUnit
        else { return [] }

        var properties: [String: String] = [:]

        if let rawValue = sample.metadata?[HKMetadataKeyBloodGlucoseMealTime] as? NSNumber,
            let value = HKBloodGlucoseMealTime(rawValue: rawValue.intValue)
        {
            properties["relation_to_meal"] = value.relationToMeal
        }

        let additionalProperties: [String: String]? = properties.isEmpty ? nil : properties

        let value = sample.quantity.doubleValue(for: unit).rounded(toPlaces: 4)

        return [
            DataLog(
                profileId: profileId,
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

extension HKBloodGlucoseMealTime {
    fileprivate var relationToMeal: String {
        switch self {
        case .preprandial:
            return "before_meal"
        case .postprandial:
            return "after_meal"
        @unknown default:
            return "unknown"
        }
    }
}
