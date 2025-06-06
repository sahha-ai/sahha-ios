import HealthKit

// TODO: Finish full implementation

extension HKCategorySample {
    func toDataLog_internal() async -> DataLog? {
        guard let sensor = SahhaSensor.from(sampleType: categoryType),
              let unit = sensor.hkUnit else { return nil }

        let value = 0.0 // TODO: Make func to get HKCategorySample values (sleep etc.)

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
