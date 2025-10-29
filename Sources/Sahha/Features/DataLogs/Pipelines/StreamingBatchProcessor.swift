import Foundation

/// A chunk of data logs ready for upload
struct DataLogChunk: Sendable {
    let requests: [DataLogRequest]
    let sizeInBytes: Int
    let priority: UploadPriority
}

/// Processes data logs as chunks and delivers them via callback
actor StreamingBatchProcessor {
    private let requestMapper: DataLogRequestMapperProtocol
    private let priorityAssigner: UploadPriorityAssignerProtocol
    private let maxChunkBytes: Int
    private let chunkSize: Int  // Max logs per chunk
    
    init(
        requestMapper: DataLogRequestMapperProtocol,
        priorityAssigner: UploadPriorityAssignerProtocol,
        maxChunkKB: Int = 150,
        chunkSize: Int = 100
    ) {
        self.requestMapper = requestMapper
        self.priorityAssigner = priorityAssigner
        self.maxChunkBytes = maxChunkKB * 1024
        self.chunkSize = chunkSize
    }
    
    /// Stream logs as chunks, invoking callback for each chunk in priority order
    func streamChunks(from logs: [DataLog], handler: @escaping @Sendable (DataLogChunk) async -> Void) async {
        await processLogsIntoChunks(logs) { chunk in
            await handler(chunk)
        }
    }
    
    /// Process logs into chunks and invoke handler for each chunk
    private func processLogsIntoChunks(
        _ logs: [DataLog],
        handler: @escaping @Sendable (DataLogChunk) async -> Void
    ) async {
        // Group by priority first to maintain priority ordering
        var logsByPriority: [UploadPriority: [DataLog]] = [:]
        for log in logs {
            let priority = priorityAssigner.assignPriority(to: log)
            logsByPriority[priority, default: []].append(log)
        }
        
        // Process each priority group, highest first
        for priority in [UploadPriority.critical, .high, .normal, .low] {
            guard let priorityLogs = logsByPriority[priority], !priorityLogs.isEmpty else {
                continue
            }
            
            await streamPriorityGroup(priorityLogs, priority: priority, handler: handler)
        }
    }
    
    /// Stream a single priority group as chunks
    private func streamPriorityGroup(
        _ logs: [DataLog],
        priority: UploadPriority,
        handler: @escaping @Sendable (DataLogChunk) async -> Void
    ) async {
        var currentChunk: [DataLogRequest] = []
        var currentBytes = 0
        let encoder = JSONEncoder()
        
        for log in logs {
            // Check if task was cancelled
            if Task.isCancelled {
                break
            }
            
            let request = requestMapper.map(log)
            
            // Estimate size of adding this request
            let estimatedRequestBytes: Int
            if let encoded = try? encoder.encode(request) {
                estimatedRequestBytes = encoded.count
            } else {
                estimatedRequestBytes = 1024  // Default estimate if encoding fails
            }
            
            // Check if adding this request would exceed limits
            let wouldExceedSize = (currentBytes + estimatedRequestBytes) > maxChunkBytes
            let wouldExceedCount = currentChunk.count >= chunkSize
            
            if wouldExceedSize || wouldExceedCount {
                // Yield current chunk if not empty
                if !currentChunk.isEmpty {
                    let chunk = DataLogChunk(
                        requests: currentChunk,
                        sizeInBytes: currentBytes,
                        priority: priority
                    )
                    await handler(chunk)
                    
                    // Reset for next chunk
                    currentChunk = []
                    currentBytes = 0
                }
            }
            
            // Add request to current chunk
            currentChunk.append(request)
            currentBytes += estimatedRequestBytes
        }
        
        // Yield final chunk if not empty
        if !currentChunk.isEmpty {
            let chunk = DataLogChunk(
                requests: currentChunk,
                sizeInBytes: currentBytes,
                priority: priority
            )
            await handler(chunk)
        }
    }
}

