import Foundation

struct RegisterProfileEndpoint: ApiEndpoint {
    let request: RegisterProfileRequest
    
    let appId: String
    let appSecret: String
    
    var path: String { "v1/oauth/profile/register/appId" }
    var method: HTTPMethod { .post }
    var queryItems: [URLQueryItem]? { nil }
    var headers: [String : String]? {["AppId": appId, "AppSecret": appSecret]}
    var body: Data? { encodeBody(request) }
}
