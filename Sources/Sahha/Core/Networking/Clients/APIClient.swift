protocol APIClient: Sendable, Interceptable {
    func send(_ request: APIRequest) async throws
    func send<T: Decodable>(_ request: APIRequest) async throws -> T
}
