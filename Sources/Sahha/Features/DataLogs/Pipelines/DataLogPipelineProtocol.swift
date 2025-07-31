protocol DataLogPipelineProtocol: Actor {
    func ingest(_ log: DataLog) async
    func ingest(_ logs: [DataLog]) async
}
