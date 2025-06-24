import Foundation

struct AuthenticationEndpoint: APIEndpoint {
    let request: AuthenticationRequest
    let appId: String
    let appSecret: String
    
    var path: String { "v1/oauth/profile/register/appId" }
    var method: HTTPMethod { .POST }
    var queryParameters: [URLQueryItem]? { nil }
    var headers: [String : String]? {["AppId": appId, "AppSecret": appSecret]}
    var body: Data? { encodeBody(request) }
}
