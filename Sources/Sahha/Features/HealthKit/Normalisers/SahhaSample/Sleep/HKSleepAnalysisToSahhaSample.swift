import HealthKit

enum HKSleepAnalysisToSahhaSample {
    static let normalise: Normaliser<HKSample, SahhaSample>.NormaliserFn = { sample in
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
        
        return [SahhaSample(
            id: sample.uuid.uuidString,
            category: metadata.biomarkerCategory.rawValue,
            type: "sleep_stage_\(sleepStage)",
            value: Double(duration).rounded(toPlaces: 4),
            unit: metadata.unitString,
            startDateTime: sample.startDate,
            endDateTime: sample.endDate,
            recordingMethod: sample.recordingMethod.stringValue,
            source: sample.sourceId
        )]
    }
}
