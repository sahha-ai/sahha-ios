import HealthKit

extension HKQuantitySample {
    func toDataLog_internal() async -> DataLog? {
        guard let sensor = SahhaSensor.from(sampleType: quantityType),
              let unit = sensor.hkUnit else { return nil }

        let value = quantity.doubleValue(for: unit)

        return DataLog(
            dataType: sensor.rawValue,
            value: value,
            source: sourceRevision.source.name,
            recordingMethod: recordingMethod,
            deviceType: sourceRevision.productType ?? "unknown",
            startDateTime: startDate,
            endDateTime: endDate,
            additionalProperties: [:] // TODO: Populate if needed later
        )
    }
}
