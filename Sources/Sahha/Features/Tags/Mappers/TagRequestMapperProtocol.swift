protocol TagRequestMapperProtocol: Sendable {
    func map(_ tag: Tag) -> TagRequest
    func map(_ tags: [Tag]) -> [TagRequest]
}
