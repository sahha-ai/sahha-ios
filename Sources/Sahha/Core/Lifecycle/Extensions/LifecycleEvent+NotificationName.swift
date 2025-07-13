import UIKit

extension LifecycleEvent {
    var notificationName: NSNotification.Name {
        switch self {
        case .start: return UIApplication.didFinishLaunchingNotification
        case .didBecomeActive: return UIApplication.didBecomeActiveNotification
        case .pause: return UIApplication.willResignActiveNotification
        case .foreground: return UIApplication.willEnterForegroundNotification
        case .background: return UIApplication.didEnterBackgroundNotification
        case .close: return UIApplication.willTerminateNotification
        case .unlock: return UIApplication.protectedDataDidBecomeAvailableNotification
        case .lock: return UIApplication.protectedDataWillBecomeUnavailableNotification
        }
    }
}
