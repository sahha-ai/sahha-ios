import Foundation

/// Persistent storage for tag batches that require persistence across app restarts.
/// Stores data with metadata about failure state, priority, and retry attempts.
/// Batches older than 3 days are automatically evicted.
actor TagDeadLetterQueue {
    private let fileManager: FileManager
    private let persistentDirectory: URL
    private let maxStoredBatches: Int
    private let maxAge: TimeInterval

    static let defaultRetentionDays: Double = 3

    init(
        fileManager: FileManager = .default,
        baseDirectory: URL,
        maxStoredBatches: Int = 500,
        retentionDays: Double = defaultRetentionDays
    ) {
        self.fileManager = fileManager
        self.persistentDirectory = baseDirectory.appendingPathComponent("PersistentQueue")
        self.maxStoredBatches = maxStoredBatches
        self.maxAge = .days(retentionDays)

        try? fileManager.createDirectory(
            at: persistentDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Persistent Storage

    @discardableResult
    func persistBatch(
        _ chunk: TagChunk,
        attemptCount: Int = 0,
        lastError: String? = nil
    ) async -> String? {
        let timestamp = Date().timeIntervalSince1970
        let id = UUID().uuidString
        let fileName = "batch_\(chunk.priority.rawValue)_\(timestamp)_\(id).json"
        let fileURL = persistentDirectory.appendingPathComponent(fileName)

        let persistedBatch = TagPersistedBatch(
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
            Sahha.log("[Tag Persistent Queue] Stored batch with \(chunk.requests.count) tags (\(reason), priority: \(chunk.priority), attempts: \(attemptCount))")

            await cleanupOldBatches()
            return id
        } catch {
            Sahha.log("[Tag Persistent Queue] Failed to persist batch: \(error.localizedDescription)")
            return nil
        }
    }

    func loadAllBatches() async -> [TagPersistedBatch] {
        guard let files = try? fileManager.contentsOfDirectory(
            at: persistentDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else {
            return []
        }

        var batches: [TagPersistedBatch] = []
        var expiredFiles: [URL] = []
        let decoder = JSONDecoder()
        let now = Date().timeIntervalSince1970

        for fileURL in files where fileURL.pathExtension == "json" {
            if let data = try? Data(contentsOf: fileURL),
               let persistedBatch = try? decoder.decode(TagPersistedBatch.self, from: data) {
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
            Sahha.log("[Tag Persistent Queue] Evicted \(expiredFiles.count) batches older than 3 days")
        }

        let sortedBatches = batches.sorted { lhs, rhs in
            if lhs.chunk.priority != rhs.chunk.priority {
                return lhs.chunk.priority > rhs.chunk.priority
            }
            return lhs.timestamp < rhs.timestamp
        }

        if !sortedBatches.isEmpty {
            let totalTags = sortedBatches.reduce(0) { $0 + $1.chunk.requests.count }
            let failedCount = sortedBatches.filter { $0.lastError != nil }.count
            Sahha.log("[Tag Persistent Queue] Loaded \(sortedBatches.count) batches (\(totalTags) tags, \(failedCount) previously failed)")
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

        Sahha.log("[Tag Persistent Queue] Cleared all persisted batches")
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
               let persistedBatch = try? decoder.decode(TagPersistedBatch.self, from: data) {
                if now - persistedBatch.timestamp > maxAge {
                    try? fileManager.removeItem(at: fileURL)
                    evictedCount += 1
                }
            }
        }

        if evictedCount > 0 {
            Sahha.log("[Tag Persistent Queue] Force evicted \(evictedCount) expired batches")
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
            Sahha.log("[Tag Persistent Queue] Cleaned up \(filesToRemove.count) old batch files")
        }
    }
}

// MARK: - Storage Models

struct TagPersistedBatch: Codable {
    let id: String
    let chunk: TagChunk
    let timestamp: TimeInterval
    let attemptCount: Int
    let lastError: String?

    var hasFailed: Bool {
        lastError != nil
    }
}
