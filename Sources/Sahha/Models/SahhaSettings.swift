public struct SahhaSettings: Sendable {
    public let environment: SahhaEnvironment
    public var framework: SahhaFramework = .ios_swift

    public init(environment: SahhaEnvironment) {
        self.environment = environment
    }
}
