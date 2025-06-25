import Foundation

struct APIRequest {
    let endpoint: String
    let method: HTTPMethod
    var queryParameters: [URLQueryItem]?
    var headers: [String : String]?
    var body: Data?
    
    init(
        endpoint: String,
        method: HTTPMethod = .GET,
        queryParameters: [URLQueryItem]? = nil,
        headers: [String : String]? = nil,
        body: Encodable? = nil
    ) {
        self.endpoint = endpoint
        self.method = method
        self.queryParameters = queryParameters
        self.headers = headers
        self.body = body != nil ? try? JSONEncoder().encode(body!) : nil
    }
}

extension APIRequest {
    mutating func addQueryParameter(name: String, value: String) {
        var existingParameters = self.queryParameters ?? []
        existingParameters.append(URLQueryItem(name: name, value: value))
        self.queryParameters = existingParameters
    }
    
    mutating func addHeader(name: String, value: String) {
        var existingHeaders = self.headers ?? [:]
        existingHeaders[name] = value
        self.headers = existingHeaders
    }
    
    mutating func setBody(_ body: Encodable) {
        self.body = try? JSONEncoder().encode(body)
    }
}
