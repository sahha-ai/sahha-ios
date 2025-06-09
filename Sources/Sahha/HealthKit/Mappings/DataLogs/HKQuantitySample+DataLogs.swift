import HealthKit

extension HKQuantitySample {
    func toDataLogs_internal() -> [DataLog]? {
        guard let sensor = SahhaSensor.from(sampleType: quantityType),
              let unit = sensor.hkUnit else { return nil }
        
        let value = quantity.doubleValue(for: unit).rounded(to: 4)
        
        // TODO: Ignore 0 value?
        
        return [.init(
            dataType: sensor.rawValue,
            value: value,
            source: sourceRevision.source.name,
            recordingMethod: recordingMethod,
            deviceType: sourceRevision.productType ?? "unknown",
            startDateTime: startDate,
            endDateTime: endDate,
            additionalProperties: additionalProperties
        )]
    }
    
    private var additionalProperties: DataLogAdditionalProperties? {
        var props = DataLogAdditionalProperties()
        
        if let value = metadata?[HKMetadataKeyHeartRateSensorLocation] {
            props[.measurementLocation] = "\(value)"
        }
        
        if let value = metadata?[HKMetadataKeyVO2MaxTestType] {
            props[.measurementMethod] = "\(value)"
        }
        
        if let value = metadata?[HKMetadataKeyHeartRateMotionContext] {
            props[.motionContext] = "\(value)"
        }
        
        if let value = metadata?[HKMetadataKeyBloodGlucoseMealTime] {
            props[.relationToMeal] = "\(value)"
        }
        
        return props.isEmpty ? nil : props
    }
}
