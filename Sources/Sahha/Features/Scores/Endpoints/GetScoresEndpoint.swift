import Foundation

struct GetScoresEndpoint: APIEndpoint {
    let types: Set<String>
    let startDateTime: Date
    let endDateTime: Date

    var path: String { "v2/score" }
    var method: HTTPMethod { .GET }
    
    var queryParameters: [URLQueryItem]? {
        var params = [URLQueryItem]()
        
        types.forEach { type in
            params.append(URLQueryItem(name: "types", value: type))
        }
        params.append(URLQueryItem(name: "startDateTime", value: startDateTime.isoDate))
        params.append(URLQueryItem(name: "endDateTime", value: endDateTime.isoDate))
        
        return params
    }
    
    var headers: [String : String]? { nil }
    var body: Data? { nil }
}
