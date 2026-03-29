protocol TagServiceProtocol: Sendable {
    func postTags(_ tags: [TagRequest]) async throws
}
