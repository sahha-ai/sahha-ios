import Foundation

struct PostErrorEndpoint: ApiEndpoint {
    let request: PostErrorRequest
    
    var path: String { "v1/error" }
    var method: HTTPMethod { .post }
    var queryItems: [URLQueryItem]? { nil }
    var headers: [String : String]? { nil }
    var body: Data? { encodeBody(request) }
}
