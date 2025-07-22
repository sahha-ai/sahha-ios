extension APIRequest {
    static func postDataLogs(_ logs: [DataLogRequest]) -> APIRequest {
        APIRequest(
            endpoint: APIEndpoints.dataLog,
            method: .POST,
            body: logs
        )
    }
}
