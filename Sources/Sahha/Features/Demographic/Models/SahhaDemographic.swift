public struct SahhaDemographic: Codable, Equatable, Sendable {
    public var gender: String?
    public var birthDate: String?
    
    public init(
        gender: String? = nil,
        birthDate: String? = nil
    ) {
        self.gender = gender
        self.birthDate = birthDate
    }
}
