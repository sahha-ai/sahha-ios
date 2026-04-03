import Foundation

/// Generic persistent storage for upload batches that require persistence across app restarts.
/// Stores data with metadata about failure state, priority, and retry attempts.
/// Batches older than 3 days are automatically evicted.
actor UnifiedDeadLetterQueue<Request: UploadableRequest> {
    private let fileManager: FileManager
    private let persistentDirectory: URL
    private let maxStoredBatches: Int
    private let maxAge: TimeInterval
    private let logLabel: String

    static var defaultRetentionDays: Double { 3 }

    init(
        fileManager: FileManager = .default,
        baseDirectory: URL,
        maxStoredBatches: Int = 500,
        retentionDays: Double = 3,
        logLabel: String = "Persistent Queue"
    ) {
        self.fileManager = fileManager
        self.persistentDirectory = baseDirectory.appendingPathComponent("PersistentQueue")
        self.maxStoredBatches = maxStoredBatches
        self.maxAge = .days(retentionDays)
        self.logLabel = logLabel

        try? fileManager.createDirectory(
            at: persistentDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Persistent Storage

    @discardableResult
    func persistBatch(
        _ chunk: UploadChunk<Request>,
        attemptCount: Int = 0,
        lastError: String? = nil
    ) async -> String? {
        let timestamp = Date().timeIntervalSince1970
        let id = UUID().uuidString
        let fileName = "batch_\(chunk.priority.rawValue)_\(timestamp)_\(id).json"
        let fileURL = persistentDirectory.appendingPathComponent(fileName)

        let persistedBatch = PersistedBatch(
            id: id,
            chunk: chunk,
            timestamp: timestamp,
            attemptCount: attemptCount,
            lastError: lastError
        )

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(persistedBatch)
            try data.write(to: fileURL)

            let reason = lastError != nil ? "after failure" : "while offline"
            Sahha.log("[\(logLabel)] Stored batch with \(chunk.requests.count) items (\(reason), priority: \(chunk.priority), attempts: \(attemptCount))")

            await cleanupOldBatches()
            return id
        } catch {
            Sahha.log("[\(logLabel)] Failed to persist batch: \(error.localizedDescription)")
            return nil
        }
    }

    func loadAllBatches() async -> [PersistedBatch<Request>] {
        guard let files = try? fileManager.contentsOfDirectory(
            at: persistentDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else {
            return []
        }

        var batches: [PersistedBatch<Request>] = []
        var expiredFiles: [URL] = []
        let decoder = JSONDecoder()
        let now = Date().timeIntervalSince1970

        for fileURL in files where fileURL.pathExtension == "json" {
            if let data = try? Data(contentsOf: fileURL),
               let persistedBatch = try? decoder.decode(PersistedBatch<Request>.self, from: data) {
                if now - persistedBatch.timestamp <= maxAge {
                    batches.append(persistedBatch)
                } else {
                    expiredFiles.append(fileURL)
                }
            }
        }

        if !expiredFiles.isEmpty {
            for fileURL in expiredFiles {
                try? fileManager.removeItem(at: fileURL)
            }
            Sahha.log("[\(logLabel)] Evicted \(expiredFiles.count) batches older than 3 days")
        }

        let sortedBatches = batches.sorted { lhs, rhs in
            if lhs.chunk.priority != rhs.chunk.priority {
                return lhs.chunk.priority > rhs.chunk.priority
            }
            return lhs.timestamp < rhs.timestamp
        }

        if !sortedBatches.isEmpty {
            let totalItems = sortedBatches.reduce(0) { $0 + $1.chunk.requests.count }
            let failedCount = sortedBatches.filter { $0.lastError != nil }.count
            Sahha.log("[\(logLabel)] Loaded \(sortedBatches.count) batches (\(totalItems) items, \(failedCount) previously failed)")
        }

        return sortedBatches
    }

    func removeBatch(withId id: String) async {
        guard let files = try? fileManager.contentsOfDirectory(
            at: persistentDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        for fileURL in files where fileURL.lastPathComponent.contains(id) {
            try? fileManager.removeItem(at: fileURL)
        }
    }

    func clearAll() async {
        guard let files = try? fileManager.contentsOfDirectory(
            at: persistentDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        for fileURL in files where fileURL.pathExtension == "json" {
            try? fileManager.removeItem(at: fileURL)
        }

        Sahha.log("[\(logLabel)] Cleared all persisted batches")
    }

    func getCount() async -> Int {
        guard let files = try? fileManager.contentsOfDirectory(
            at: persistentDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return 0
        }

        return files.filter { $0.pathExtension == "json" }.count
    }

    func getStatistics() async -> PersistenceStatistics {
        let batches = await loadAllBatches()
        let failedBatches = batches.filter { $0.lastError != nil }
        let totalItems = batches.reduce(0) { $0 + $1.chunk.requests.count }

        return PersistenceStatistics(
            totalBatches: batches.count,
            totalItems: totalItems,
            failedBatches: failedBatches.count,
            oldestTimestamp: batches.first?.timestamp,
            retentionDays: maxAge / 86400
        )
    }

    func evictExpired() async {
        guard let files = try? fileManager.contentsOfDirectory(
            at: persistentDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        var evictedCount = 0
        let decoder = JSONDecoder()
        let now = Date().timeIntervalSince1970

        for fileURL in files where fileURL.pathExtension == "json" {
            if let data = try? Data(contentsOf: fileURL),
               let persistedBatch = try? decoder.decode(PersistedBatch<Request>.self, from: data) {
                if now - persistedBatch.timestamp > maxAge {
                    try? fileManager.removeItem(at: fileURL)
                    evictedCount += 1
                }
            }
        }

        if evictedCount > 0 {
            Sahha.log("[\(logLabel)] Force evicted \(evictedCount) expired batches")
        }
    }

    private func cleanupOldBatches() async {
        guard let files = try? fileManager.contentsOfDirectory(
            at: persistentDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else {
            return
        }

        let jsonFiles = files.filter { $0.pathExtension == "json" }

        guard jsonFiles.count > maxStoredBatches else { return }

        let sortedFiles = jsonFiles.sorted { file1, file2 in
            let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            return date1 < date2
        }

        let filesToRemove = sortedFiles.prefix(jsonFiles.count - maxStoredBatches)
        for fileURL in filesToRemove {
            try? fileManager.removeItem(at: fileURL)
        }

        if !filesToRemove.isEmpty {
            Sahha.log("[\(logLabel)] Cleaned up \(filesToRemove.count) old batch files")
        }
    }
}

// MARK: - Storage Models

struct PersistedBatch<Request: UploadableRequest>: Codable {
    let id: String
    let chunk: UploadChunk<Request>
    let timestamp: TimeInterval
    let attemptCount: Int
    let lastError: String?

    var hasFailed: Bool {
        lastError != nil
    }
}

struct PersistenceStatistics: Sendable {
    let totalBatches: Int
    let totalItems: Int
    let failedBatches: Int
    let oldestTimestamp: TimeInterval?
    let retentionDays: Double

    var description: String {
        let oldest = oldestTimestamp.map { formatAge(Date().timeIntervalSince1970 - $0) } ?? "N/A"
        return """
        PersistentQueue Statistics:
        - Total batches: \(totalBatches)
        - Total items: \(totalItems)
        - Failed batches: \(failedBatches)
        - Oldest batch: \(oldest)
        - Retention: \(Int(retentionDays)) days
        """
    }

    private func formatAge(_ seconds: TimeInterval) -> String {
        let hours = seconds / 3600
        if hours < 1 {
            return "\(Int(seconds / 60)) minutes ago"
        } else if hours < 24 {
            return String(format: "%.1f hours ago", hours)
        } else {
            return String(format: "%.1f days ago", hours / 24)
        }
    }
}
