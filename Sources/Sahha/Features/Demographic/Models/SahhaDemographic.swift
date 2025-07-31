public struct SahhaDemographic: Codable, Equatable, Sendable {
    public var gender: String? = nil
    public var birthDate: String? = nil
}

extension SahhaDemographic {
    var isEmpty: Bool {
        return gender == nil && birthDate == nil
    }
    
    var isComplete: Bool {
        return gender != nil && birthDate != nil
    }
    
    mutating func mergeWith(_ other: SahhaDemographic) {
        var result = self
        if result.isEmpty {
            result = other
        } else {
            result.gender = self.gender ?? other.gender
            result.birthDate = self.birthDate ?? other.birthDate            
        }
        self = result
    }
}
