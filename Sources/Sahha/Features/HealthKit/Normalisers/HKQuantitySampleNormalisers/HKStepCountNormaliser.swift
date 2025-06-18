import HealthKit

final class HKStepCountNormaliser: HKNormaliser {
    func normalise(_ sample: HKSample) async -> [any DataLogType] {
        guard let quantitySample = sample as? HKQuantitySample,
              quantitySample.quantityType == HKQuantityType(.stepCount) else {
            return []
        }
        
        let commonData = await extractCommonData(from: sample)
        let steps = quantitySample.quantity.doubleValue(for: .count())
        
        return [DataLog(
            parentId: nil,
            dataType: "steps",
            value: steps,
            source: commonData.source,
            recordingMethod: commonData.recordingMethod,
            deviceType: commonData.deviceType,
            startDate: commonData.startDate,
            endDate: commonData.endDate,
            additionalProperties: nil
        )]
    }
}
