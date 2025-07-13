extension LifecycleEvent {
    var appEvent: String {
        switch self {
        case .start: return "app_start"
        case .didBecomeActive: return "app_resume"
        case .pause: return "app_pause"
        case .foreground: return "app_foreground"
        case .background: return "app_background"
        case .close: return "app_close"
        case .unlock: return "device_unlock"
        case .lock: return "device_lock"
        }
    }
}
