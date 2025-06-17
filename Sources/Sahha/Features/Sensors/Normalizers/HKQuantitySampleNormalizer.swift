import Foundation
import HealthKit

class HKQuantitySampleNormalizer: HKSampleNormalizer {
    func normalize(_ sample: HKSample, source: String, deviceType: String, recordingMethod: DataLogRecordingMethod, startDate: Date, endDate: Date) -> [DataLog]? {
        guard let quantitySample = sample as? HKQuantitySample,
              let sensor = SahhaSensor.from(sampleType: quantitySample.quantityType),
              let unit = sensor.hkUnit else { return nil }
        
        let value = quantitySample.quantity.doubleValue(for: unit).rounded(to: 4)
        
        return [DataLog(
            parentId: nil,
            dataType: sensor.rawValue,
            value: value,
            source: source,
            recordingMethod: recordingMethod,
            deviceType: deviceType,
            startDate: startDate,
            endDate: endDate,
            additionalProperties: nil // TODO
        )]
    }
}
