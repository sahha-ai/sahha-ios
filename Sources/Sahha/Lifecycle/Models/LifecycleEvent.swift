enum LifecycleEvent: String {
    case appStart = "app_start"
    case appOpen = "app_open"
    case appResume = "app_resume"
    case appPause = "app_pause"
    case appForeground = "app_foreground"
    case appBackground = "app_background"
    case appClose = "app_close"
    case appDestroy = "app_destroy"
    case deviceUnlock = "device_unlock"
    case deviceLock = "device_lock"
}
