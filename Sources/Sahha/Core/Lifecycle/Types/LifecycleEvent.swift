enum LifecycleEvent: String, Sendable, CaseIterable {
    case start
    case didBecomeActive
    case pause
    case foreground
    case background
    case close
    case unlock
    case lock
}
