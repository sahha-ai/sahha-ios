import HealthKit

extension HKCategorySample {
    func toDataLogs_internal() -> [DataLog]? {
        guard let sensor = SahhaSensor.from(sampleType: categoryType) else { return nil }
        
        switch sensor {
        case .sleep:
            return makeSleepLog()
        default:
            return nil
        }
    }
    
    private func makeSleepLog() -> [DataLog]? {
        guard let sleepStage = HKCategoryValueSleepAnalysis(rawValue: value) else { return nil }
        
        let duration = Calendar.current.dateComponents([.minute], from: startDate, to: endDate).minute ?? 0
        let value = Double(duration).rounded(to: 4)
        
        // TODO: Ignore 0 value?
        
        return [.init(
            dataType: "sleep_stage_" + sleepStage.name,
            value: value,
            source: sourceRevision.source.name,
            recordingMethod: recordingMethod,
            deviceType: sourceRevision.productType ?? "unknown",
            startDateTime: startDate,
            endDateTime: endDate,
            additionalProperties: nil
        )]
    }
}
