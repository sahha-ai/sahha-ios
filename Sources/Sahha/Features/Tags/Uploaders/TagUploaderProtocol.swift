protocol TagUploaderProtocol: Actor {
    func enqueueTags(_ tags: [Tag]) async
    func retryPendingUploads() async
    func getDLQStatistics() async -> PersistenceStatistics
    func dispose() async
}

extension UnifiedUploader: TagUploaderProtocol where Item == Tag, Request == TagRequest {
    func enqueueTags(_ tags: [Tag]) async {
        await enqueueItems(tags)
    }
}
