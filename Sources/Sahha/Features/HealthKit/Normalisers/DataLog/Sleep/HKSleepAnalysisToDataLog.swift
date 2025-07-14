import HealthKit

enum HKSleepAnalysisToDataLog {
    static let normalise: Normaliser<HKSample, DataLog>.NormaliserFn = { sample in
        guard
            let sample = sample as? HKCategorySample,
            let metadata = SensorMapper.metadata(for: sample.sampleType),
            metadata.sensor == .sleep,
            let unit = metadata.hkUnit
        else {
            return []
        }
        
        let sleepStage = HKCategoryValueSleepAnalysis(rawValue: sample.value)?.name ?? "unknown"
        let duration = Calendar.current.dateComponents([.minute], from: sample.startDate, to: sample.endDate).minute ?? 0
        
        return [DataLog(
            logType: metadata.logType,
            dataType: "sleep_stage_\(sleepStage)",
            value: Double(duration).rounded(toPlaces: 4),
            unit: metadata.unitString,
            source: sample.sourceId,
            recordingMethod: sample.recordingMethod,
            deviceType: sample.deviceType,
            startDate: sample.startDate,
            endDate: sample.endDate,
        )]
    }
}
