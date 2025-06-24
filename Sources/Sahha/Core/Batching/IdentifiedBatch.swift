struct IdentifiedBatch<T: Codable & Sendable>: Sendable {
    let id: String
    let batch: [T]
}
