import UIKit

extension LifecycleEvent {
    var notification: Notification.Name? {
        switch self {
        case .app_create: return UIApplication.didFinishLaunchingNotification
        case .app_resume: return UIApplication.didBecomeActiveNotification
        case .app_pause: return UIApplication.willResignActiveNotification
        case .app_foreground: return UIApplication.willEnterForegroundNotification
        case .app_background: return UIApplication.didEnterBackgroundNotification
        case .app_destroy: return UIApplication.willTerminateNotification
        case .app_unlocked: return UIApplication.protectedDataDidBecomeAvailableNotification
        case .app_locked: return UIApplication.protectedDataWillBecomeUnavailableNotification
        }
    }
}
