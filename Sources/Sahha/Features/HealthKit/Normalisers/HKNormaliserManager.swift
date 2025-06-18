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
        let recordingMethod = getRecordingMethod(sample)
        
        func getRecordingMethod(_ sample: HKSample) -> DataLogRecordingMethod {
            guard let value = sample.metadata?[HKMetadataKeyWasUserEntered] as? NSNumber else {
                return .unknown
            }
            return value.boolValue ? .manual : .automatic
        }
        
        return (source, deviceType, startDate, endDate, recordingMethod)
    }
}

protocol HKNormaliserManagerProtocol: Sendable {
    func normalise(sample: HKSample) async -> [any DataLogType]
}

final class HKNormaliserManager: HKNormaliserManagerProtocol {
    private let normalisers: [HKSampleType:  any HKNormaliser]
    
    init(normalisers: [HKSampleType:  any HKNormaliser]) {
        self.normalisers = normalisers
    }
    
    func normalise(sample: HKSample) async -> [any DataLogType] {
        guard let normaliser = normalisers[sample.sampleType] else {
            return []
        }
        return await normaliser.normalise(sample)
    }
}
