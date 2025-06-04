struct ApiErrorResponse: Codable {
    struct Error: Codable {
        var origin: String
        var errors: [String]
    }
    var title: String
    var statusCode: Int
    var location: String
    var errors: [Error]
}
