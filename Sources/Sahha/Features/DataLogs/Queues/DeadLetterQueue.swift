import Foundation

/// Manages batches that have permanently failed after all retries
actor DeadLetterQueue {
    private let fileManager: FileManager
    private let deadLetterDirectory: URL
    private let maxDeadLetterSize: Int // Max number of dead letter files
    
    init(
        fileManager: FileManager = .default,
        baseDirectory: URL,
        maxDeadLetterSize: Int = 100
    ) {
        self.fileManager = fileManager
        self.deadLetterDirectory = baseDirectory.appendingPathComponent("DeadLetterQueue")
        self.maxDeadLetterSize = maxDeadLetterSize
        
        // Create directory if needed
        try? fileManager.createDirectory(
            at: deadLetterDirectory,
            withIntermediateDirectories: true
        )
    }
    
    /// Add a batch to the dead letter queue
    func enqueueFailed(
        batch: [DataLogRequest],
        error: Error,
        attemptCount: Int
    ) async {
        let timestamp = Date().timeIntervalSince1970
        let fileName = "dead_\(timestamp)_\(UUID().uuidString).json"
        let fileURL = deadLetterDirectory.appendingPathComponent(fileName)
        
        let deadLetter = DeadLetterBatch(
            batch: batch,
            errorDescription: error.localizedDescription,
            attemptCount: attemptCount,
            timestamp: timestamp
        )
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(deadLetter)
            try data.write(to: fileURL)
            
            print("[Dead Letter] Enqueued \(batch.count) logs after \(attemptCount) attempts: \(error.localizedDescription)")
            
            // Clean up old dead letters if we exceed the limit
            await cleanupOldDeadLetters()
        } catch {
            print("[Dead Letter] Failed to enqueue: \(error.localizedDescription)")
        }
    }
    
    /// Get all dead letter batches for manual recovery
    func getAllDeadLetters() async -> [DeadLetterBatch] {
        guard let files = try? fileManager.contentsOfDirectory(
            at: deadLetterDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }
        
        var deadLetters: [DeadLetterBatch] = []
        let decoder = JSONDecoder()
        
        for fileURL in files where fileURL.pathExtension == "json" {
            if let data = try? Data(contentsOf: fileURL),
               let deadLetter = try? decoder.decode(DeadLetterBatch.self, from: data) {
                deadLetters.append(deadLetter)
            }
        }
        
        return deadLetters.sorted { $0.timestamp < $1.timestamp }
    }
    
    /// Get count of dead letter batches
    func getCount() async -> Int {
        guard let files = try? fileManager.contentsOfDirectory(
            at: deadLetterDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return 0
        }
        
        return files.filter { $0.pathExtension == "json" }.count
    }
    
    /// Retry all dead letter batches (manual recovery)
    func retryAll() async -> [DataLogRequest] {
        let deadLetters = await getAllDeadLetters()
        var allBatches: [DataLogRequest] = []
        
        for deadLetter in deadLetters {
            allBatches.append(contentsOf: deadLetter.batch)
        }
        
        // Clear dead letter queue after retrieval
        await clearAll()
        
        print("[Dead Letter] Retrying \(deadLetters.count) dead letter batches (\(allBatches.count) total logs)")
        
        return allBatches
    }
    
    /// Clear all dead letter batches
    func clearAll() async {
        guard let files = try? fileManager.contentsOfDirectory(
            at: deadLetterDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }
        
        for fileURL in files where fileURL.pathExtension == "json" {
            try? fileManager.removeItem(at: fileURL)
        }
        
        print("[Dead Letter] Cleared all dead letter batches")
    }
    
    /// Remove old dead letters to prevent unbounded growth
    private func cleanupOldDeadLetters() async {
        guard let files = try? fileManager.contentsOfDirectory(
            at: deadLetterDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else {
            return
        }
        
        let jsonFiles = files.filter { $0.pathExtension == "json" }
        
        guard jsonFiles.count > maxDeadLetterSize else { return }
        
        // Sort by creation date, oldest first
        let sortedFiles = jsonFiles.sorted { file1, file2 in
            let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            return date1 < date2
        }
        
        // Remove oldest files to get back to limit
        let filesToRemove = sortedFiles.prefix(jsonFiles.count - maxDeadLetterSize)
        for fileURL in filesToRemove {
            try? fileManager.removeItem(at: fileURL)
        }
        
        if !filesToRemove.isEmpty {
            print("[Dead Letter] Cleaned up \(filesToRemove.count) old dead letter files")
        }
    }
}

/// A batch that has permanently failed
struct DeadLetterBatch: Codable {
    let batch: [DataLogRequest]
    let errorDescription: String
    let attemptCount: Int
    let timestamp: TimeInterval
}

