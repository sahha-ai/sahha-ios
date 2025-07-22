import HealthKit

enum SleepToSahhaSample {
    static func normalise(_ samples: [HKSample], sensor: SahhaSensor) -> [SahhaSample] {
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

            return SahhaSample(
                id: categorySample.uuid.uuidString,
                category: sensor.category.rawValue,
                type: "sleep_stage_\(sleepStage)",
                value: Double(duration).rounded(toPlaces: 4),
                unit: sensor.unitString,
                startDateTime: categorySample.startDate,
                endDateTime: categorySample.endDate,
                recordingMethod: categorySample.recordingMethod.stringValue,
                source: categorySample.sourceId,
            )
        }
    }
}
