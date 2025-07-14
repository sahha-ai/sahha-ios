import HealthKit

enum FallbackDataLogNormaliser {
    static let normalise: Normaliser<HKSample, DataLog>.NormaliserFn = { sample in
        guard
            let sample = sample as? HKQuantitySample,
            let metadata = SensorMapper.metadata(for: sample.sampleType),
            let unit = metadata.hkUnit
        else {
            return []
        }
        
        return [DataLog(
            logType: metadata.logType,
            dataType: metadata.sensor.rawValue,
            value: sample.quantity.doubleValue(for: unit).rounded(toPlaces: 4),
            unit: metadata.unitString,
            source: sample.sourceId,
            recordingMethod: sample.recordingMethod,
            deviceType: sample.deviceType,
            startDate: sample.startDate,
            endDate: sample.endDate,
        )]
    }
}
