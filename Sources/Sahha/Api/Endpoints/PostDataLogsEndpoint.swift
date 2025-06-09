import Foundation

struct PostDataLogsEndpoint: ApiEndpoint {
    let request: [DataLogRequest]
    
    var path: String { "v1/profile/data/log" }
    var method: HTTPMethod { .post }
    var queryItems: [URLQueryItem]? { nil }
    var headers: [String : String]? { nil }
    var body: Data? { encodeBody(request) }
}
