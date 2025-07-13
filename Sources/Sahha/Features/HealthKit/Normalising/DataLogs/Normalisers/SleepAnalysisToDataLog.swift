import HealthKit

enum SleepAnalysisToDataLog {
    static let normalise: NormalisingEngine<HKSample, DataLog>.Normaliser = { sample in
        guard let sample = sample as? HKCategorySample,
              let sensor = SahhaSensor.sensor(for: sample.categoryType),
              sensor == .sleep
        else { return [] }
        
        let sleepStage = HKCategoryValueSleepAnalysis(rawValue: sample.value)?.name ?? "unknown"
        let duration = Calendar.current.dateComponents([.minute], from: sample.startDate, to: sample.endDate).minute ?? 0
        
        return [DataLog(
            logType: sensor.logType,
            dataType: "sleep_stage_\(sleepStage)",
            value: Double(duration).rounded(toPlaces: 4),
            unit: sensor.unitString,
            source: sample.sourceId,
            recordingMethod: sample.recordingMethod,
            deviceType: sample.deviceType,
            startDate: sample.startDate,
            endDate: sample.endDate,
        )]
    }
}
