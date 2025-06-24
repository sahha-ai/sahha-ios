import Foundation

struct PutDeviceInfoEndpoint: APIEndpoint {
    let request: DeviceInfoRequest
   
    var path: String { "v1/oauth/profile/register/appId" }
    var method: HTTPMethod { .POST }
    var queryParameters: [URLQueryItem]? { nil }
    var headers: [String : String]? { nil }
    var body: Data? { encodeBody(request) }
}
