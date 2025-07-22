import Foundation

extension APIRequest {
    static func getBiomarkers(
        categories: Set<SahhaBiomarkerCategory>,
        types: Set<SahhaBiomarkerType>,
        startDateTime: Date,
        endDateTime: Date
    ) -> APIRequest {
        var queryParameters = [URLQueryItem]()
        categories.forEach { category in queryParameters.append(URLQueryItem(name: "categories", value: category.rawValue)) }
        types.forEach { type in queryParameters.append(URLQueryItem(name: "types", value: type.rawValue)) }
        queryParameters.append(URLQueryItem(name: "startDateTime", value: startDateTime.isoDate))
        queryParameters.append(URLQueryItem(name: "endDateTime", value: endDateTime.isoDate))

        return APIRequest(
            endpoint: APIEndpoints.biomarker,
            queryParameters: queryParameters,
            requiresAuth: true
        )
    }
}
