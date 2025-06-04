import Foundation

struct RefreshTokenEndpoint: ApiEndpoint {
    let request: RefreshTokenRequest
    
    var path: String { "v1/oauth/profile/refreshToken" }
    var method: HTTPMethod { .post }
    var queryItems: [URLQueryItem]? { nil }
    var headers: [String : String]? { nil }
    var body: Data? { encodeBody(request) }
}
