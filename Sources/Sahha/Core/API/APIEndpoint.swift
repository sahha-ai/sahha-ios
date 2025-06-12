import Foundation

protocol ApiEndpoint {
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
}
