import Foundation

actor AggregationStore {
    private let baseDirectory: URL
    private let storage = FileSystemStorage()
    private let formatter = AggregationFormatter()

    init(baseDirectory: URL) {
        self.baseDirectory = baseDirectory
    }

    // TODO: Implement
    func store(_ logs: [DataLog]) async throws {
//        for log in logs {
//            let fileURL = resolveFileURL(for: log)
//            let line = formatter.format(log) + "\n"
//            try storage.ensureDirectoryExists(at: fileURL.deletingLastPathComponent())
//            try storage.append(Data(line.utf8), to: fileURL)
//        }
    }

    private func resolveFileURL(for log: DataLog) -> URL {
        let date = log.startDateTime
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let year = String(format: "%04d", components.year ?? 0)
        let month = String(format: "%02d", components.month ?? 0)
        let day = String(format: "%02d", components.day ?? 0)

        // TODO: Placeholder path until windowed formatting is introduced
        return baseDirectory
            .appendingPathComponent(log.dataType)
            .appendingPathComponent(log.deviceType)
            .appendingPathComponent(log.source)
            .appendingPathComponent(year)
            .appendingPathComponent(month)
            .appendingPathComponent(day)
            .appendingPathComponent("placeholder.txt")
    }
}
