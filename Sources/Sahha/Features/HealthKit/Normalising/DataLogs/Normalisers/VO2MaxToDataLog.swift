import HealthKit

enum VO2MaxToDataLog {
    static let normalise: NormalisingEngine<HKSample, DataLog>.Normaliser = { sample in
        guard let sample = sample as? HKQuantitySample,
              let sensor = SahhaSensor.sensor(for: sample.quantityType),
              sensor == .vo2_max,
              let unit = sensor.hkUnit
        else { return [] }
        
        let extractor = VO2MaxMetadataExtractor()
        let additionalProperties = extractor.extract(from: sample)
        
        return [DataLog(
            logType: sensor.logType,
            dataType: sensor.rawValue,
            value: sample.quantity.doubleValue(for: unit).rounded(toPlaces: 4),
            unit: sensor.unitString,
            source: sample.sourceId,
            recordingMethod: sample.recordingMethod,
            deviceType: sample.deviceType,
            startDate: sample.startDate,
            endDate: sample.endDate,
            additionalProperties: additionalProperties
        )]
    }
}
