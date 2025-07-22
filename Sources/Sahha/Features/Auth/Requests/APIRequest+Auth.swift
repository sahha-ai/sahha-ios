extension APIRequest {
    static func authenticate(appId: String, appSecret: String, externalId: String) -> APIRequest {
        struct Body: Codable {
            let externalId: String
        }

        return APIRequest(
            endpoint: APIEndpoints.register,
            method: .POST,
            headers: ["AppId": appId, "AppSecret": appSecret],
            body: Body(externalId: externalId)
        )
    }

    static func refreshToken(_ refreshToken: String) -> APIRequest {
        struct Body: Codable {
            let refreshToken: String
        }

        return APIRequest(
            endpoint: APIEndpoints.refreshToken,
            method: .POST,
            body: Body(refreshToken: refreshToken)
        )
    }
}
