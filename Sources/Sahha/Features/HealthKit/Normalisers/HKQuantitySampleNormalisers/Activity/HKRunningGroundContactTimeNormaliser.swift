import HealthKit

struct HKRunningGroundContactTimeNormaliser: HKNormaliser {
    func normalise(sample: HKSample) -> [DataLog]? {
        guard #available(iOS 16.0, *) else { return nil }
        
        let type = HKQuantityType.quantityType(forIdentifier: .runningGroundContactTime)
        
        guard let quantitySample = sample as? HKQuantitySample, quantitySample.quantityType == type else {
            return nil
        }
        
        let value = quantitySample.quantity.doubleValue(for: .secondUnit(with: .milli)).rounded(toPlaces: 4)
        
        let log = DataLog(
            parentId: nil,
            logType: quantitySample.logType,
            dataType: quantitySample.dataType,
            value: value,
            unit: "ms",
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
