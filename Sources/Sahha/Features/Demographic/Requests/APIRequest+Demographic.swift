extension APIRequest {
    static func getDemographic() -> APIRequest {
        APIRequest(
            endpoint: APIEndpoints.demographic,
            requiresAuth: true
        )
    }

    static func updateDemographic(_ demographic: SahhaDemographic) -> APIRequest {
        APIRequest(
            endpoint: APIEndpoints.demographic,
            method: .PATCH,
            body: demographic,
            requiresAuth: true,
        )
    }
}
