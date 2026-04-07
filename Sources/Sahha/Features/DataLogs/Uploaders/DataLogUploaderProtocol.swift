protocol DataLogUploaderProtocol: Actor {
    func enqueueLogs(_ logs: [DataLog]) async
    func retryPendingUploads() async
    func getDLQStatistics() async -> PersistenceStatistics
    func dispose() async
}

extension UnifiedUploader: DataLogUploaderProtocol where Item == DataLog, Request == DataLogRequest {
    func enqueueLogs(_ logs: [DataLog]) async {
        await enqueueItems(logs)
    }
}
