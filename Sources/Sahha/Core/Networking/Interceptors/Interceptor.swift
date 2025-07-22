typealias NextAPIRequest = (APIRequest) async throws -> APIResponse

protocol Interceptor: Sendable, Identifiable {
    associatedtype ID: Hashable = String
    
    var id: ID { get }
    var priority: Int { get }
    
    func intercept(request: APIRequest, next: NextAPIRequest) async throws -> APIResponse
}
