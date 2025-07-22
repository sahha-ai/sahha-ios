import HealthKit

enum SleepToDataLog {
    static func normalise(_ samples: [HKSample], sensor: SahhaSensor) -> [DataLog] {
        guard sensor == .sleep else {
            return []
        }

        return samples.compactMap { sample in
            guard let categorySample = sample as? HKCategorySample,
                let unit = sensor.hkUnit
            else {
                return nil
            }

            let sleepStage = HKCategoryValueSleepAnalysis(rawValue: categorySample.value)?.name ?? "unknown"
            let duration = Calendar.current.dateComponents([.minute], from: categorySample.startDate, to: categorySample.endDate).minute ?? 0

            return DataLog(
                logType: sensor.logType,
                dataType: "sleep_stage_\(sleepStage)",
                value: Double(duration).rounded(toPlaces: 4),
                unit: sensor.unitString,
                source: categorySample.sourceId,
                recordingMethod: categorySample.recordingMethod,
                deviceType: categorySample.deviceType,
                startDate: categorySample.startDate,
                endDate: categorySample.endDate
            )
        }
    }
}
