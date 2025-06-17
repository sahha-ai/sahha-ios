import Foundation
import HealthKit

class HKCategorySampleNormalizer: HKSampleNormalizer {
    func normalize(_ sample: HKSample, source: String, deviceType: String, recordingMethod: DataLogRecordingMethod, startDate: Date, endDate: Date) -> [DataLog]? {
        guard let categorySample = sample as? HKCategorySample,
              let sensor = SahhaSensor.from(sampleType: categorySample.categoryType) else { return nil }
        
        switch sensor {
        case .sleep:
            guard let sleepStage = HKCategoryValueSleepAnalysis(rawValue: categorySample.value) else { return nil }
            let duration = Calendar.current.dateComponents([.minute], from: startDate, to: endDate).minute ?? 0
            let value = Double(duration).rounded(to: 4)
            
            guard value > 0 else { return nil }
            
            return [DataLog(
                dataType: "sleep_stage_" + sleepStage.name,
                value: value,
                source: source,
                recordingMethod: recordingMethod,
                deviceType: deviceType,
                startDate: startDate,
                endDate: endDate
            )]
        default:
            return nil
        }
    }
}
