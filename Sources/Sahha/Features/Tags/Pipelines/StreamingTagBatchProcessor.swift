import Foundation

/// A chunk of tags ready for upload
struct TagChunk: Sendable, Codable {
    let requests: [TagRequest]
    let sizeInBytes: Int
    let priority: TagPriority
}

/// Processes tags as chunks and delivers them via callback
actor StreamingTagBatchProcessor {
    private let requestMapper: TagRequestMapperProtocol
    private let priorityAssigner: TagPriorityAssignerProtocol
    private let maxChunkBytes: Int
    private let chunkSize: Int

    init(
        requestMapper: TagRequestMapperProtocol,
        priorityAssigner: TagPriorityAssignerProtocol,
        config: UploadConfig = .default
    ) {
        self.requestMapper = requestMapper
        self.priorityAssigner = priorityAssigner
        self.maxChunkBytes = config.maxChunkKB * 1024
        self.chunkSize = config.maxLogsPerChunk
    }

    func streamChunks(from tags: [Tag], handler: @escaping @Sendable (TagChunk) async -> Void) async {
        await processTagsIntoChunks(tags, handler: handler)
    }

    private func processTagsIntoChunks(
        _ tags: [Tag],
        handler: @escaping @Sendable (TagChunk) async -> Void
    ) async {
        var tagsByPriority: [TagPriority: [Tag]] = [:]
        for tag in tags {
            let priority = priorityAssigner.assignPriority(to: tag)
            tagsByPriority[priority, default: []].append(tag)
        }

        for priority in [TagPriority.critical, .high, .normal, .low] {
            guard let priorityTags = tagsByPriority[priority], !priorityTags.isEmpty else {
                continue
            }
            await streamPriorityGroup(priorityTags, priority: priority, handler: handler)
        }
    }

    private func streamPriorityGroup(
        _ tags: [Tag],
        priority: TagPriority,
        handler: @escaping @Sendable (TagChunk) async -> Void
    ) async {
        var currentChunk: [TagRequest] = []
        var currentBytes = 0
        let encoder = JSONEncoder()

        for tag in tags {
            if Task.isCancelled { break }

            let request = requestMapper.map(tag)

            let estimatedRequestBytes: Int
            if let encoded = try? encoder.encode(request) {
                estimatedRequestBytes = encoded.count
            } else {
                estimatedRequestBytes = 1024
            }

            let wouldExceedSize = (currentBytes + estimatedRequestBytes) > maxChunkBytes
            let wouldExceedCount = currentChunk.count >= chunkSize

            if wouldExceedSize || wouldExceedCount {
                if !currentChunk.isEmpty {
                    let chunk = TagChunk(
                        requests: currentChunk,
                        sizeInBytes: currentBytes,
                        priority: priority
                    )
                    await handler(chunk)
                    currentChunk = []
                    currentBytes = 0
                }
            }

            currentChunk.append(request)
            currentBytes += estimatedRequestBytes
        }

        if !currentChunk.isEmpty {
            let chunk = TagChunk(
                requests: currentChunk,
                sizeInBytes: currentBytes,
                priority: priority
            )
            await handler(chunk)
        }
    }
}
