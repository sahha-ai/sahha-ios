import HealthKit

protocol HKNormaliser: Normaliser where Input == HKSample, Output == [any DataLogType] {
    func extractCommonData(from sample: HKSample) async -> (source: String, deviceType: String, startDate: Date, endDate: Date, recordingMethod: DataLogRecordingMethod)
}

extension HKNormaliser {
    func extractCommonData(from sample: HKSample) async -> (source: String, deviceType: String, startDate: Date, endDate: Date, recordingMethod: DataLogRecordingMethod) {
        let source = sample.sourceRevision.source.bundleIdentifier
        let deviceType = sample.sourceRevision.productType ?? "unknown"
        let startDate = sample.startDate
        let endDate = sample.endDate
        var recordingMethod: DataLogRecordingMethod = .unknown
        
        if let wasUserEntered = sample.metadata?[HKMetadataKeyWasUserEntered] as? NSNumber {
            recordingMethod = wasUserEntered.boolValue ? .manual : .automatic
        }
        
        return (source, deviceType, startDate, endDate, recordingMethod)
    }
}
