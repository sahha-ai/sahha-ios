extension APIRequest {
    static func postError(_ error: ErrorLog) -> APIRequest {
        APIRequest(
            endpoint: APIEndpoints.error,
            method: .POST,
            body: error
        )
    }
}
