import Foundation

extension SahhaDemographic {
    
    init(from response: SahhaDemographicResponse) {
        self.init(
            age: response.age,
            gender: response.gender,
            country: response.country,
            birthCountry: response.birthCountry,
            ethnicity: response.ethnicity,
            occupation: response.occupation,
            industry: response.industry,
            incomeRange: response.incomeRange,
            education: response.education,
            relationship: response.relationship,
            locale: response.locale,
            livingArrangement: response.livingArrangement,
            birthDate: response.birthDate
        )
    }

    func toRequest() -> SahhaDemographicRequest {
        return SahhaDemographicRequest(
            age: self.age,
            gender: self.gender,
            country: self.country,
            birthCountry: self.birthCountry,
            ethnicity: self.ethnicity,
            occupation: self.occupation,
            industry: self.industry,
            incomeRange: self.incomeRange,
            education: self.education,
            relationship: self.relationship,
            locale: self.locale,
            livingArrangement: self.livingArrangement,
            birthDate: self.birthDate
        )
    }
}
