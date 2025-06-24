import Foundation

protocol APIEndpoint: Sendable {
    var path: String { get }
    var method: HTTPMethod { get }
    var queryParameters: [URLQueryItem]? { get }
    var headers: [String: String]? { get }
    var body: Data? { get }
}

extension APIEndpoint {
    func encodeBody<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }
    
    func addHeaders(_ headers: [String: String]) -> APIEndpoint {
        ModifiedEndpoint(base: self, headers: headers)
    }

    func addQueryParameters(_ parameters: [URLQueryItem]) -> APIEndpoint {
        ModifiedEndpoint(base: self, queryParameters: parameters)
    }

    func setBody<T: Encodable>(_ encodable: T) -> APIEndpoint {
        ModifiedEndpoint(base: self, body: encodeBody(encodable))
    }
}

// Concrete endpoint struct to support modifications
private struct ModifiedEndpoint: APIEndpoint {
    let path: String
    let method: HTTPMethod
    let queryParameters: [URLQueryItem]?
    let headers: [String: String]?
    let body: Data?
    
    init(
        base: APIEndpoint,
        headers: [String: String]? = nil,
        queryParameters: [URLQueryItem]? = nil,
        body: Data? = nil
    ) {
        self.path = base.path
        self.method = base.method

        // Merge query parameters
        if let baseParams = base.queryParameters,
            let extraParams = queryParameters
        {
            self.queryParameters = baseParams + extraParams
        } else {
            self.queryParameters = base.queryParameters ?? queryParameters
        }

        // Merge headers
        if let baseHeaders = base.headers, let newHeaders = headers {
            self.headers = baseHeaders.merging(newHeaders)
        } else {
            self.headers = base.headers ?? headers
        }

        // Overwrite or preserve body
        self.body = body ?? base.body
    }
}
