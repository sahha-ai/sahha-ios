enum LifecycleEvent: String, CaseIterable {
    case app_create
    case app_resume
    case app_pause
    case app_foreground
    case app_background
    case app_destroy
    case app_locked
    case app_unlocked
}
