import Foundation

protocol BackgroundTriggerDelegate: AnyObject, Sendable {
    func triggerDidFire(source: String, fallbackData: [DataLog]?) async
}
