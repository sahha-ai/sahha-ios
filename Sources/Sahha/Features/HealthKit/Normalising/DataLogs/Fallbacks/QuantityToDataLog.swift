import HealthKit
import Foundation

enum QuantityToDataLog {
    static let normalise: NormalisingEngine<HKSample, DataLog>.Normaliser = { sample in
        guard let sample = sample as? HKQuantitySample,
              let sensor = SahhaSensor.sensor(for: sample.quantityType),
              let unit = sensor.hkUnit
        else { return [] }
        
        return [DataLog(
            parentId: nil,
            logType: sensor.logType,
            dataType: sensor.rawValue,
            value: sample.quantity.doubleValue(for: unit).rounded(toPlaces: 4),
            unit: sensor.unitString,
            source: sample.sourceId,
            recordingMethod: sample.recordingMethod,
            deviceType: sample.deviceType,
            startDate: sample.startDate,
            endDate: sample.endDate,
        )]
    }
}
