protocol APIServiceProtocol: Sendable {
    func registerInterceptor(_ interceptor: APIInterceptor) async
    func request(_ request: APIRequest) async throws
    func request<T: Decodable>(_ request: APIRequest) async throws -> T
}
