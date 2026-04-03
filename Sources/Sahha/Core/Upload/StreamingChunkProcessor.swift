import Foundation

/// Generic batch processor that groups items by priority and chunks them for upload.
actor StreamingChunkProcessor<Item: Sendable, Request: UploadableRequest> {
    private let mapItem: @Sendable (Item) -> Request
    private let assignPriority: @Sendable (Item) -> UploadPriority
    private let maxChunkBytes: Int
    private let chunkSize: Int

    init(
        mapItem: @escaping @Sendable (Item) -> Request,
        assignPriority: @escaping @Sendable (Item) -> UploadPriority,
        config: UploadConfig = .default
    ) {
        self.mapItem = mapItem
        self.assignPriority = assignPriority
        self.maxChunkBytes = config.maxChunkKB * 1024
        self.chunkSize = config.maxLogsPerChunk
    }

    func streamChunks(
        from items: [Item],
        handler: @escaping @Sendable (UploadChunk<Request>) async -> Void
    ) async {
        var itemsByPriority: [UploadPriority: [Item]] = [:]
        for item in items {
            let priority = assignPriority(item)
            itemsByPriority[priority, default: []].append(item)
        }

        for priority in [UploadPriority.critical, .high, .normal, .low] {
            guard let priorityItems = itemsByPriority[priority], !priorityItems.isEmpty else {
                continue
            }
            await streamPriorityGroup(priorityItems, priority: priority, handler: handler)
        }
    }

    private func streamPriorityGroup(
        _ items: [Item],
        priority: UploadPriority,
        handler: @escaping @Sendable (UploadChunk<Request>) async -> Void
    ) async {
        var currentChunk: [Request] = []
        var currentBytes = 0
        let encoder = JSONEncoder()

        for item in items {
            if Task.isCancelled { break }

            let request = mapItem(item)

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
                    let chunk = UploadChunk<Request>(
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
            let chunk = UploadChunk<Request>(
                requests: currentChunk,
                sizeInBytes: currentBytes,
                priority: priority
            )
            await handler(chunk)
        }
    }
}
