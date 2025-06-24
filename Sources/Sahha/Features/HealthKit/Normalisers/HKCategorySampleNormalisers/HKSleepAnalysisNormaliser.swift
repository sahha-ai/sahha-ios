import HealthKit

final class HKSleepAnalysisNormaliser: HKNormaliser {
    func normalise(_ sample: HKSample) async -> [any DataLogType] {
        guard let categorySample = sample as? HKCategorySample,
            categorySample.categoryType == HKCategoryType(.sleepAnalysis),
            let sleepStage = HKCategoryValueSleepAnalysis(rawValue: categorySample.value) else {
            return []
        }

        let commonData = await extractCommonData(from: sample)
        let duration = Calendar.current.dateComponents([.minute],from: commonData.startDate,to: commonData.endDate).minute ?? 0
        let value = Double(duration).rounded(to: 4)

        return [
            DataLog(
                parentId: nil,
                dataType: "sleep_stage_" + sleepStage.name,
                value: value,
                source: commonData.source,
                recordingMethod: commonData.recordingMethod,
                deviceType: commonData.deviceType,
                startDate: commonData.startDate,
                endDate: commonData.endDate,
                additionalProperties: nil
            )
        ]
    }
}
