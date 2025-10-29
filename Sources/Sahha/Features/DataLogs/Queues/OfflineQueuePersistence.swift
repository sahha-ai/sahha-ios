import Foundation

/// Manages persistent storage of chunks when offline to survive app restarts
actor OfflineQueuePersistence {
    private let fileManager: FileManager
    private let queueDirectory: URL
    private let maxQueueFiles: Int
    
    init(
        fileManager: FileManager = .default,
        baseDirectory: URL,
        maxQueueFiles: Int = 500
    ) {
        self.fileManager = fileManager
        self.queueDirectory = baseDirectory.appendingPathComponent("OfflineQueue")
        self.maxQueueFiles = maxQueueFiles
        
        // Create directory if needed
        try? fileManager.createDirectory(
            at: queueDirectory,
            withIntermediateDirectories: true
        )
    }
    
    /// Persist a chunk to disk (for offline accumulation)
    func persistChunk(_ chunk: DataLogChunk) async {
        let timestamp = Date().timeIntervalSince1970
        let fileName = "chunk_\(chunk.priority.rawValue)_\(timestamp)_\(UUID().uuidString).json"
        let fileURL = queueDirectory.appendingPathComponent(fileName)
        
        let persistedChunk = PersistedChunk(
            chunk: chunk,
            timestamp: timestamp,
            priority: chunk.priority
        )
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(persistedChunk)
            try data.write(to: fileURL)
            
            print("[Offline Queue] Persisted chunk with \(chunk.requests.count) logs (priority: \(chunk.priority))")
            
            // Cleanup old files if we exceed limit
            await cleanupOldChunks()
        } catch {
            print("[Offline Queue] Failed to persist chunk: \(error.localizedDescription)")
        }
    }
    
    /// Load all persisted chunks from disk (on app startup or network restoration)
    func loadAllChunks() async -> [DataLogChunk] {
        guard let files = try? fileManager.contentsOfDirectory(
            at: queueDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else {
            return []
        }
        
        var chunks: [(DataLogChunk, TimeInterval)] = []
        let decoder = JSONDecoder()
        
        for fileURL in files where fileURL.pathExtension == "json" {
            if let data = try? Data(contentsOf: fileURL),
               let persistedChunk = try? decoder.decode(PersistedChunk.self, from: data) {
                chunks.append((persistedChunk.chunk, persistedChunk.timestamp))
            }
        }
        
        // Sort by priority first, then by timestamp (oldest first within priority)
        let sortedChunks = chunks.sorted { lhs, rhs in
            if lhs.0.priority != rhs.0.priority {
                return lhs.0.priority > rhs.0.priority  // Higher priority first
            }
            return lhs.1 < rhs.1  // Older timestamp first
        }
        
        let loadedChunks = sortedChunks.map { $0.0 }
        
        if !loadedChunks.isEmpty {
            print("[Offline Queue] Loaded \(loadedChunks.count) persisted chunks from disk")
        }
        
        return loadedChunks
    }
    
    /// Clear a specific chunk file after successful upload
    func clearChunk(withId id: String) async {
        guard let files = try? fileManager.contentsOfDirectory(
            at: queueDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }
        
        for fileURL in files where fileURL.lastPathComponent.contains(id) {
            try? fileManager.removeItem(at: fileURL)
        }
    }
    
    /// Clear all persisted chunks
    func clearAll() async {
        guard let files = try? fileManager.contentsOfDirectory(
            at: queueDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }
        
        for fileURL in files where fileURL.pathExtension == "json" {
            try? fileManager.removeItem(at: fileURL)
        }
        
        print("[Offline Queue] Cleared all persisted chunks")
    }
    
    /// Get count of persisted chunks
    func getCount() async -> Int {
        guard let files = try? fileManager.contentsOfDirectory(
            at: queueDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return 0
        }
        
        return files.filter { $0.pathExtension == "json" }.count
    }
    
    /// Remove old chunks to prevent unbounded growth
    private func cleanupOldChunks() async {
        guard let files = try? fileManager.contentsOfDirectory(
            at: queueDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else {
            return
        }
        
        let jsonFiles = files.filter { $0.pathExtension == "json" }
        
        guard jsonFiles.count > maxQueueFiles else { return }
        
        // Sort by creation date, oldest first
        let sortedFiles = jsonFiles.sorted { file1, file2 in
            let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            return date1 < date2
        }
        
        // Remove oldest files to get back to limit
        let filesToRemove = sortedFiles.prefix(jsonFiles.count - maxQueueFiles)
        for fileURL in filesToRemove {
            try? fileManager.removeItem(at: fileURL)
        }
        
        if !filesToRemove.isEmpty {
            print("[Offline Queue] Cleaned up \(filesToRemove.count) old chunk files")
        }
    }
}

/// A chunk with persistence metadata
struct PersistedChunk: Codable {
    let chunk: DataLogChunk
    let timestamp: TimeInterval
    let priority: UploadPriority
}

/// Make DataLogChunk Codable for persistence
extension DataLogChunk: Codable {}

