protocol APIClientProtocol: Sendable {
    func send(_ request: APIRequest) async throws
    /// Decodes the response body. A 204 or an empty body throws "No Content".
    func send<T: Decodable>(_ request: APIRequest) async throws -> T
    /// Decodes the response body, returning `nil` for a 204 or an empty body.
    /// Use for endpoints where "nothing stored yet" is a normal state, not a failure.
    func sendOptional<T: Decodable>(_ request: APIRequest) async throws -> T?
}
