import Foundation

struct PostDataLogsEndpoint: APIEndpoint {
    let request: [DataLogRequest]?
    
    var path: String { "v1/profile/data/log" }
    var method: HTTPMethod { .POST }
    var queryParameters: [URLQueryItem]? { nil }
    var headers: [String : String]? { nil }
    var body: Data? { encodeBody(request) }
}
