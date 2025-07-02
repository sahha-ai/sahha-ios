import HealthKit

struct HKRunningSpeedNormaliser: HKNormaliser {
    func normalise(sample: HKSample) -> [DataLog]? {
        guard #available(iOS 16.0, *) else { return nil }
        
        let type = HKQuantityType.quantityType(forIdentifier: .runningSpeed)
        
        guard let quantitySample = sample as? HKQuantitySample, quantitySample.quantityType == type, let unit = quantitySample.unit else {
            return nil
        }

        let value = quantitySample.quantity.doubleValue(for: unit).rounded(toPlaces: 4)

        let log = DataLog(
            parentId: nil,
            logType: quantitySample.logType,
            dataType: quantitySample.dataType,
            value: value,
            unit: quantitySample.unitString,
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
