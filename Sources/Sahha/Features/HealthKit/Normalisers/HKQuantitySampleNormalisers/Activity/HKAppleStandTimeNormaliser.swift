import HealthKit

struct HKAppleStandTimeNormaliser: HKNormaliser {
    func normalise(sample: HKSample) -> [DataLog]? {
        let type = HKQuantityType.quantityType(forIdentifier: .appleStandTime)
        
        guard let quantitySample = sample as? HKQuantitySample,
            quantitySample.quantityType == type,
            let sensor = SahhaSensor.sensor(for: quantitySample.quantityType),
            let unit = sensor.hkUnit
        else {
            return nil
        }

        let value = quantitySample.quantity.doubleValue(for: unit).rounded(toPlaces: 4)

        let log = DataLog(
            parentId: nil,
            logType: sensor.logType,
            dataType: sensor.rawValue,
            value: value,
            unit: sensor.unitString,
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
