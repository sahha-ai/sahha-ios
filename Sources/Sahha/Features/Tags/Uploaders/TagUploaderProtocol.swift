protocol TagUploaderProtocol: Actor {
    func enqueue(_ chunk: TagChunk) async
    func enqueueTags(_ tags: [Tag]) async
    func retryPendingUploads() async
    func dispose() async
}
