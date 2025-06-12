import Foundation

struct PutDeviceInformationEndpoint: ApiEndpoint {
    let request: DeviceInfoRequest
    
    var path: String { "v1/profile/deviceInformation" }
    var method: HTTPMethod { .put }
    var queryItems: [URLQueryItem]? { nil }
    var headers: [String : String]? { nil }
    var body: { encodeBody(request) }
}
