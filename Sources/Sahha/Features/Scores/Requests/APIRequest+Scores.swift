import Foundation

extension APIRequest {
    static func getScores(
        types: Set<SahhaScoreType>,
        startDateTime: Date,
        endDateTime: Date
    ) -> APIRequest {
        var queryParameters = [URLQueryItem]()
        types.forEach { type in queryParameters.append(URLQueryItem(name: "types", value: type.rawValue)) }
        queryParameters.append(URLQueryItem(name: "startDateTime", value: startDateTime.isoDate))
        queryParameters.append(URLQueryItem(name: "endDateTime", value: endDateTime.isoDate))

        return APIRequest(
            endpoint: APIEndpoints.score,
            queryParameters: queryParameters,
            requiresAuth: true
        )
    }
}
