import HealthKit

final class HKSleepAnalysisToSahhaSampleNormaliser: HKSampleToSahhaSampleNormaliserProtocol {
    func normalise(_ sample: HKSample) -> [SahhaSample] {
        guard let sample = sample as? HKCategorySample,
              let sensor = sample.categoryType.sahhaSensor,
            sensor == .sleep
        else { return [] }

        let sleepStage = HKCategoryValueSleepAnalysis(rawValue: sample.value)?.name ?? "unknown"
        let duration = Calendar.current.dateComponents([.minute], from: sample.startDate, to: sample.endDate).minute ?? 0
        let value = Double(duration).rounded(toPlaces: 4)

        return [
            SahhaSample(
                id: sample.uuid.uuidString,
                category: sensor.dataLogType.stringValue,
                type: "sleep_stage_\(sleepStage)",
                value: value,
                unit: sensor.unitString,
                startDateTime: sample.startDate,
                endDateTime: sample.endDate,
                recordingMethod: sample.recordingMethod.stringValue,
                source: sample.sourceId
            )
        ]
    }
}
