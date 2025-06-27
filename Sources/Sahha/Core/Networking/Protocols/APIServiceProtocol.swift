protocol APIServiceProtocol: Sendable {
    func registerInterceptor(_ interceptor: APIInterceptor) async
    func send(_ request: APIRequest) async throws
    func send<T: Decodable>(_ request: APIRequest) async throws -> T
}
