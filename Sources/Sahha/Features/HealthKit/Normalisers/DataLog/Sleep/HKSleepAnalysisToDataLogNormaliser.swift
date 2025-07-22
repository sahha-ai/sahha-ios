import HealthKit

enum HKSleepAnalysisToDataLogNormaliser {
    static func normalise(_ sample: HKSample) -> [DataLog] {
        guard let sample = sample as? HKCategorySample,
            let sensor = sample.categoryType.sahhaSensor,
            sensor == .sleep
        else { return [] }

        let sleepStage = HKCategoryValueSleepAnalysis(rawValue: sample.value)?.name ?? "unknown"
        let duration = Calendar.current.dateComponents([.minute], from: sample.startDate, to: sample.endDate).minute ?? 0
        let value = Double(duration).rounded(toPlaces: 4)

        return [
            DataLog(
                logType: sensor.logType,
                dataType: "sleep_stage_\(sleepStage)",
                value: value,
                unit: sensor.unitString,
                source: sample.sourceId,
                recordingMethod: sample.recordingMethod,
                deviceType: sample.deviceType,
                startDate: sample.startDate,
                endDate: sample.endDate
            )
        ]
    }
}
