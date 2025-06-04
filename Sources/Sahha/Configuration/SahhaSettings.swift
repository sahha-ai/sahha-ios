public struct SahhaSettings: Codable, Sendable, Equatable {
    public let environment: SahhaEnvironment
    public var framework: SahhaFramework = .ios_swift
    
    public init(environment: SahhaEnvironment) {
        self.environment = environment
    }
}
