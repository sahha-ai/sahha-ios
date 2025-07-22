protocol DataLogPipelineProviding: Actor, Disposable {
    func ingest(_ logs: [DataLog]) async throws
}
