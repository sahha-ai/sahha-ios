import HealthKit

enum SleepAnalysisToSahhaSample {
    static let normalise: NormalisingEngine<HKSample, SahhaSample>.Normaliser = { sample in
        guard let sample = sample as? HKCategorySample,
              let sensor = SahhaSensor.sensor(for: sample.categoryType),
              sensor == .sleep
        else { return [] }
        
        let sleepStage = HKCategoryValueSleepAnalysis(rawValue: sample.value)?.name ?? "unknown"
        let duration = Calendar.current.dateComponents([.minute], from: sample.startDate, to: sample.endDate).minute ?? 0
        
        return [SahhaSample(
            id: sample.uuid.uuidString,
            category: sensor.biomarkerCategory.rawValue,
            type: "sleep_stage_\(sleepStage)",
            value: Double(duration).rounded(toPlaces: 4),
            unit: sensor.unitString,
            startDateTime: sample.startDate,
            endDateTime: sample.endDate,
            recordingMethod: sample.recordingMethod.stringValue,
            source: sample.sourceId,
            stats: []
        )]
    }
}
