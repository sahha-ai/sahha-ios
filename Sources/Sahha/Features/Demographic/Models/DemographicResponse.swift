struct DemographicResponse: Codable, Sendable, Equatable {
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

extension DemographicResponse {
    init(from request: DemographicRequest) {
        self.age = request.age
        self.gender = request.gender
        self.country = request.country
        self.birthCountry = request.birthCountry
        self.ethnicity = request.ethnicity
        self.occupation = request.occupation
        self.industry = request.industry
        self.incomeRange = request.incomeRange
        self.education = request.education
        self.relationship = request.relationship
        self.locale = request.locale
        self.livingArrangement = request.livingArrangement
        self.birthDate = request.birthDate
    }
}
