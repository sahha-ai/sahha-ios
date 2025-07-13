import HealthKit
import Foundation

enum QuantityToSahhaSample {
    static let normalise: NormalisingEngine<HKSample, SahhaSample>.Normaliser = { sample in
        guard let sample = sample as? HKQuantitySample,
              let sensor = SahhaSensor.sensor(for: sample.quantityType),
              let unit = sensor.hkUnit
        else { return [] }
        
        return [SahhaSample(
            id: sample.uuid.uuidString,
            category: sensor.biomarkerCategory.rawValue,
            type: sensor.rawValue,
            value: sample.quantity.doubleValue(for: unit).rounded(toPlaces: 4),
            unit: sensor.unitString,
            startDateTime: sample.startDate,
            endDateTime: sample.endDate,
            recordingMethod: sample.recordingMethod.stringValue,
            source: sample.sourceId,
            stats: []
        )]
    }
}
