import HealthKit

enum HKBloodGlucoseToDataLogNormaliser {
    static func normalise(_ sample: HKSample) -> [DataLog] {
        guard let sample = sample as? HKQuantitySample,
            let sensor = sample.quantityType.sahhaSensor,
            sensor == .blood_glucose,
            let unit = sensor.hkUnit
        else { return [] }

        var properties: [String: String] = [:]

        if let rawValue = sample.metadata?[HKMetadataKeyHeartRateSensorLocation] as? NSNumber,
            let value = HKHeartRateSensorLocation(rawValue: rawValue.intValue)
        {
            properties["sensor_location"] = value.stringValue
        }

        if let rawValue = sample.metadata?[HKMetadataKeyHeartRateMotionContext] as? NSNumber,
            let value = HKHeartRateMotionContext(rawValue: rawValue.intValue)
        {
            properties["motion_context"] = value.stringValue
        }

        let additionalProperties: [String: String]? = properties.isEmpty ? nil : properties

        let value = sample.quantity.doubleValue(for: unit).rounded(toPlaces: 4)

        return [
            DataLog(
                logType: sensor.logType,
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
