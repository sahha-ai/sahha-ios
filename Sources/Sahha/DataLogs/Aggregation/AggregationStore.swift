import Foundation

actor AggregationStore {
    private let baseDirectory: URL
    private let storage: FileSystemStorage

    init(baseDirectory: URL, storage: FileSystemStorage = FileSystemStorage()) {
        self.baseDirectory = baseDirectory
        self.storage = storage
    }

    // TODO: Implement me!
    func store(_ logs: [DataLog]) async throws {}
    
    func deleteAll() async throws {
        guard storage.directoryExists(at: baseDirectory) else { return }
        try storage.delete(at: baseDirectory)
    }

    private func resolveFileURL(for log: DataLog) -> URL {
        let date = log.startDateTime
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let year = String(format: "%04d", components.year ?? 0)
        let month = String(format: "%02d", components.month ?? 0)
        let day = String(format: "%02d", components.day ?? 0)
        
        let dataType = log.dataType
        let rule = AggregationConfig.rule(for: dataType)!
        let windowSize = rule.windowSize
        let function = rule.function

        let intervalSince1970 = date.timeIntervalSince1970
        let startTimestamp = floor(intervalSince1970 / windowSize) * windowSize
        let endTimestamp = startTimestamp + windowSize - 0.001

        let windowStartDate = Date(timeIntervalSince1970: startTimestamp)
        let windowEndDate = Date(timeIntervalSince1970: endTimestamp)

        let windowStart = windowStartDate.timestamp
        let windowEnd = windowEndDate.timestampMillis

        let filename = "\(windowStart)_\(windowEnd)_\(function.rawValue).txt"
        
        return baseDirectory
            .appendingPathComponent(dataType)
            .appendingPathComponent(log.deviceType)
            .appendingPathComponent(log.source)
            .appendingPathComponent(year)
            .appendingPathComponent(month)
            .appendingPathComponent(day)
            .appendingPathComponent(filename)
    }
}
