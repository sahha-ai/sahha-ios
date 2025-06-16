struct DemographicRequest: Codable, Sendable, Equatable {
    public var age: Int?
    public var gender: String?
    public var country: String?
    public var birthCountry: String?
    public var ethnicity: String?
    public var occupation: String?
    public var industry: String?
    public var incomeRange: String?
    public var education: String?
    public var relationship: String?
    public var locale: String?
    public var livingArrangement: String?
    public var birthDate: String?
}

extension DemographicRequest {
    init(from response: DemographicResponse) {
        self.age = response.age
        self.gender = response.gender
        self.country = response.country
        self.birthCountry = response.birthCountry
        self.ethnicity = response.ethnicity
        self.occupation = response.occupation
        self.industry = response.industry
        self.incomeRange = response.incomeRange
        self.education = response.education
        self.relationship = response.relationship
        self.locale = response.locale
        self.livingArrangement = response.livingArrangement
        self.birthDate = response.birthDate
    }
}
