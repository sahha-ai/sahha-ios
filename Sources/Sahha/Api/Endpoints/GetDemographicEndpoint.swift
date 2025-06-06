import Foundation

struct GetDemographicEndpoint: ApiEndpoint {
    var path: String { "v1/profile/demographic" }
    var method: HTTPMethod { .get }
    var queryItems: [URLQueryItem]? { nil }
    var headers: [String : String]? { nil }
    var body: Data? { nil }
}
