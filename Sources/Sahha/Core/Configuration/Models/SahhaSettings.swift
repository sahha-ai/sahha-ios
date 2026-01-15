public struct SahhaSettings: Sendable {
    public let environment: SahhaEnvironment
    public var framework: SahhaFramework = .ios_swift
    
    /// When enabled, uses CoreMotion pedometer to trigger background data collection
    /// and provide fallback step data when HealthKit is unavailable.
    /// Requires `NSMotionUsageDescription` in Info.plist.
    /// Default: `false`
    public var enableMotionTrigger: Bool = false

    public init(environment: SahhaEnvironment, enableMotionTrigger: Bool = false) {
        self.environment = environment
        self.enableMotionTrigger = enableMotionTrigger
    }
}

extension SahhaSettings: Equatable {
    public static func == (lhs: SahhaSettings, rhs: SahhaSettings) -> Bool {
        lhs.environment == rhs.environment && 
        lhs.framework == rhs.framework &&
        lhs.enableMotionTrigger == rhs.enableMotionTrigger
    }
    
    func isDifferent(from other: SahhaSettings) -> Bool {
        return self != other
    }
}
