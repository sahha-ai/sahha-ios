import HealthKit

struct HKBloodPressureSystolicNormaliser: HKNormaliser {
    func normalise(sample: HKSample) -> [DataLog]? {
        let type = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)
        
        guard let quantitySample = sample as? HKQuantitySample, quantitySample.quantityType == type else {
            return nil
        }
        
        let value = quantitySample.quantity.doubleValue(for: .millimeterOfMercury()).rounded(toPlaces: 4)
        
        let log = DataLog(
            parentId: nil,
            logType: quantitySample.logType,
            dataType: quantitySample.dataType,
            value: value,
            unit: "mmHg",
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
