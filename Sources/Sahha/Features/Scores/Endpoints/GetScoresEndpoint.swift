import Foundation

struct GetScoresEndpoint: ApiEndpoint {
    let types: Set<String>
    let startDateTime: Date
    let endDateTime: Date

    var path: String { "v2/score" }
    var method: HTTPMethod { .GET }
    
    var queryItems: [URLQueryItem]? {
        var items = [URLQueryItem]()
        
        types.forEach { type in
            items.append(URLQueryItem(name: "types", value: type))
        }
        items.append(URLQueryItem(name: "startDateTime", value: startDateTime.isoDate))
        items.append(URLQueryItem(name: "endDateTime", value: endDateTime.isoDate))
        
        return items
    }
    
    var headers: [String : String]? { nil }
    var body: Data? { nil }
}
