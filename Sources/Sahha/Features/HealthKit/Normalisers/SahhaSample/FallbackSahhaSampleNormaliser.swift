import HealthKit

enum FallbackSahhaSampleNormaliser {
    static let normalise: Normaliser<HKSample, SahhaSample>.NormaliserFn = { sample in
        guard
            let sample = sample as? HKQuantitySample,
            let metadata = SensorMapper.metadata(for: sample.sampleType),
            let unit = metadata.hkUnit
        else {
            return []
        }
        
        return [SahhaSample(
            id: sample.uuid.uuidString,
            category: metadata.biomarkerCategory.rawValue,
            type: metadata.sensor.rawValue,
            value: sample.quantity.doubleValue(for: unit).rounded(toPlaces: 4),
            unit: metadata.unitString,
            startDateTime: sample.startDate,
            endDateTime: sample.endDate,
            recordingMethod: sample.recordingMethod.stringValue,
            source: sample.sourceId
        )]
    }
}
