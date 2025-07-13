import HealthKit

enum BloodGlucoseToDataLog {
    static let normalise: NormalisingEngine<HKSample, DataLog>.Normaliser = { sample in
        guard let sample = sample as? HKQuantitySample,
              let sensor = SahhaSensor.sensor(for: sample.sampleType),
              sensor == .blood_glucose,
              let unit = sensor.hkUnit
        else { return [] }
        
        let extractor = BloodGlucoseMetadataExtractor()
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
