import Foundation

/// Unified persistent storage for all data logs that require persistence
/// Stores data with metadata about failure state, priority, and retry attempts
/// All storage is persistent - survives app restarts and offline periods
/// Batches older than 3 days are automatically evicted
actor DeadLetterQueue {
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
        
        // Create directory if needed
        try? fileManager.createDirectory(
            at: persistentDirectory,
            withIntermediateDirectories: true
        )
    }
    
    // MARK: - Persistent Storage
    
   
    @discardableResult
    func persistBatch(
        _ chunk: DataLogChunk,
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
            print("[Persistent Queue] Stored batch with \(chunk.requests.count) logs (\(reason), priority: \(chunk.priority), attempts: \(attemptCount))")
            
            // Cleanup old files if we exceed limit
            await cleanupOldBatches()
            return id
        } catch {
            print("[Persistent Queue] Failed to persist batch: \(error.localizedDescription)")
            return nil
        }
    }

    func loadAllBatches() async -> [PersistedBatch] {
        guard let files = try? fileManager.contentsOfDirectory(
            at: persistentDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else {
            return []
        }
        
        var batches: [PersistedBatch] = []
        var expiredFiles: [URL] = []
        let decoder = JSONDecoder()
        let now = Date().timeIntervalSince1970
        
        for fileURL in files where fileURL.pathExtension == "json" {
            if let data = try? Data(contentsOf: fileURL),
               let persistedBatch = try? decoder.decode(PersistedBatch.self, from: data) {
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
            print("[Persistent Queue] Evicted \(expiredFiles.count) batches older than 3 days")
        }
        
        let sortedBatches = batches.sorted { lhs, rhs in
            if lhs.chunk.priority != rhs.chunk.priority {
                return lhs.chunk.priority > rhs.chunk.priority  // Higher priority first
            }
            return lhs.timestamp < rhs.timestamp  // Older timestamp first
        }
        
        if !sortedBatches.isEmpty {
            let totalLogs = sortedBatches.reduce(0) { $0 + $1.chunk.requests.count }
            let failedCount = sortedBatches.filter { $0.lastError != nil }.count
            print("[Persistent Queue] Loaded \(sortedBatches.count) batches (\(totalLogs) logs, \(failedCount) previously failed)")
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
        
        print("[Persistent Queue] Cleared all persisted batches")
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
        let totalLogs = batches.reduce(0) { $0 + $1.chunk.requests.count }
        
        return PersistenceStatistics(
            totalBatches: batches.count,
            totalLogs: totalLogs,
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
               let persistedBatch = try? decoder.decode(PersistedBatch.self, from: data) {
                if now - persistedBatch.timestamp > maxAge {
                    try? fileManager.removeItem(at: fileURL)
                    evictedCount += 1
                }
            }
        }
        
        if evictedCount > 0 {
            print("[Persistent Queue] Force evicted \(evictedCount) expired batches")
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
            print("[Persistent Queue] Cleaned up \(filesToRemove.count) old batch files")
        }
    }
}

// MARK: - Storage Models

struct PersistedBatch: Codable {
    let id: String                     // Unique identifier for removal after upload
    let chunk: DataLogChunk            // The actual data to upload
    let timestamp: TimeInterval        // When this was first persisted
    let attemptCount: Int              // Number of upload attempts (0 = never tried)
    let lastError: String?             // Last error if any (nil = offline storage, not failed)
    
    var hasFailed: Bool {
        lastError != nil
    }
}

struct PersistenceStatistics: Sendable {
    let totalBatches: Int
    let totalLogs: Int
    let failedBatches: Int
    let oldestTimestamp: TimeInterval?
    let retentionDays: Double
    
    var description: String {
        let oldest = oldestTimestamp.map { formatAge(Date().timeIntervalSince1970 - $0) } ?? "N/A"
        return """
        PersistentQueue Statistics:
        - Total batches: \(totalBatches)
        - Total logs: \(totalLogs)
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


