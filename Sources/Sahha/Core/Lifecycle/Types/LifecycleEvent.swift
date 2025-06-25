enum LifecycleEvent: String, Sendable, CaseIterable {
    case appStart
    case appDidBecomeActive
    case appPause
    case appForeground
    case appBackground
    case appClose
    case deviceUnlock
    case deviceLock
}
