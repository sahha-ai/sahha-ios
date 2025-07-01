import HealthKit

struct HKRestingHeartRateNormaliser: HKNormaliser {
    func normalise(sample: HKSample) -> [DataLog]? {
        let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)
        
        guard let quantitySample = sample as? HKQuantitySample, quantitySample.quantityType == type else {
            return nil
        }
        
        let value = quantitySample.quantity.doubleValue(for: .count().unitDivided(by: .minute())).rounded(toPlaces: 4)
        
        let log = DataLog(
            parentId: nil,
            logType: quantitySample.logType,
            dataType: quantitySample.dataType,
            value: value,
            unit: "bpm",
            source: quantitySample.sourceId,
            recordingMethod: quantitySample.recordingMethod,
            deviceType: quantitySample.deviceType,
            startDate: quantitySample.startDate,
            endDate: quantitySample.endDate,
            additionalProperties: nil
        )
        
        return [log]
    }
}
