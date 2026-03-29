protocol TagPipelineProtocol: Actor {
    func ingest(_ tag: Tag) async
    func ingest(_ tags: [Tag]) async
}
