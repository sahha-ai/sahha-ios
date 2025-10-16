public struct SahhaSettings: Sendable {
    public let environment: SahhaEnvironment
    public var framework: SahhaFramework = .ios_swift

    public init(environment: SahhaEnvironment) {
        self.environment = environment
    }
}

extension SahhaSettings: Equatable {
    public static func == (lhs: SahhaSettings, rhs: SahhaSettings) -> Bool {
        lhs.environment == rhs.environment && lhs.framework == rhs.framework
    }
    
    func isDifferent(from other: SahhaSettings) -> Bool {
        return self != other
    }
}
