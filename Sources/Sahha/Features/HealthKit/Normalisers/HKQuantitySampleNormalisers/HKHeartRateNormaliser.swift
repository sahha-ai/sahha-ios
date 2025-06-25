import Foundation
import HealthKit

struct HKHeartRateNormaliser: HKNormaliser {
    func normalise(sample: HKSample) -> [DataLog]? {
        guard let quantitySample = sample as? HKQuantitySample,
            quantitySample.quantityType == HKQuantityType.quantityType(forIdentifier: .heartRate)
        else {
            return nil
        }
        let value = quantitySample.quantity.doubleValue(for: HKUnit(from: "count/min"))
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
