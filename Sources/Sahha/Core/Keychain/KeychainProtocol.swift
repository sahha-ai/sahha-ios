protocol KeychainProtocol<T>: Sendable where T: Codable & Sendable {
    associatedtype T
    func save(_ value: T) async throws
    func retrieve() async throws -> T?
    func delete() async throws
}
