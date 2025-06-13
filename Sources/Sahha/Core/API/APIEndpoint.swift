import Foundation

protocol ApiEndpoint: Sendable {
    var path: String { get }
    var method: HTTPMethod { get }
    var queryItems: [URLQueryItem]? { get }
    var headers: [String: String]? { get }
    var body: Data? { get }
}

extension ApiEndpoint {
    func encodeBody<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }
    
    func withHeaders(_ newHeaders: [String: String]) -> ApiEndpoint {
        ModifiedEndpoint(base: self, headers: newHeaders)
    }
}

// Concrete endpoint struct to support header modifications
struct ModifiedEndpoint: ApiEndpoint, Sendable {
    let path: String
    let method: HTTPMethod
    let queryItems: [URLQueryItem]?
    let headers: [String: String]?
    let body: Data?
    
    init(base: ApiEndpoint, headers: [String: String]) {
        self.path = base.path
        self.method = base.method
        self.queryItems = base.queryItems
        self.body = base.body
        var mergedHeaders = base.headers ?? [:]
        for (key, value) in headers {
            mergedHeaders[key] = value
        }
        self.headers = mergedHeaders
    }
}
