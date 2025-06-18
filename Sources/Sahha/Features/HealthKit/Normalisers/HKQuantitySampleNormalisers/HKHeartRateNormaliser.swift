import HealthKit

final class HKHeartRateNormaliser: HKNormaliser {
    func normalise(_ sample: HKSample) async -> [any DataLogType] {
        guard let quantitySample = sample as? HKQuantitySample,
              quantitySample.quantityType == HKQuantityType(.heartRate) else {
            return []
        }
        
        let commonData = await extractCommonData(from: sample)
        let value = quantitySample.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
        
        return [DataLog(
            parentId: nil,
            dataType: "heart_rate",
            value: value,
            source: commonData.source,
            recordingMethod: commonData.recordingMethod,
            deviceType: commonData.deviceType,
            startDate: commonData.startDate,
            endDate: commonData.endDate,
            additionalProperties: nil
        )]
    }
}
