import Foundation
import HealthKit

struct HKSleepAnalysisNormaliser: HKNormaliser {
    func normalise(sample: HKSample) -> [DataLog]? {
        let type = HKQuantityType.categoryType(forIdentifier: .sleepAnalysis)

        guard let categorySample = sample as? HKCategorySample, categorySample.categoryType == type else {
            return nil
        }
        
        let sleepStage = HKCategoryValueSleepAnalysis(rawValue: categorySample.value)?.name ?? "unknown"
        let duration = Calendar.current.dateComponents([.minute], from: categorySample.startDate, to: categorySample.endDate).minute ?? 0
        let value = Double(duration).rounded(toPlaces: 4)

        return [
            .init(
                parentId: nil,
                logType: categorySample.logType,
                dataType: "sleep_stage_\(sleepStage)",
                value: value,
                unit: "minute",
                source: categorySample.sourceId,
                recordingMethod: categorySample.recordingMethod,
                deviceType: categorySample.deviceType,
                startDate: categorySample.startDate,
                endDate: categorySample.endDate,
                additionalProperties: nil
            )
        ]
    }
}

extension HKCategoryValueSleepAnalysis {
    fileprivate var name: String {
        switch self {
        case .inBed: return "in_bed"
        case .awake: return "awake"
        case .asleepCore: return "light"
        case .asleepDeep: return "deep"
        case .asleepREM: return "rem"
        case .asleepUnspecified, .asleep: return "sleeping"
        @unknown default: return "unknown"
        }
    }
}
