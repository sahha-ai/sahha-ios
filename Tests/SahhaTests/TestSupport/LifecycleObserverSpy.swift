import Foundation
@testable import Sahha

/// Lifecycle-observer double: records registrations and lets tests deliver events
/// deterministically (awaiting every listener) instead of via NotificationCenter.
/// Holds listeners strongly so test fixtures stay alive without extra bookkeeping.
final actor LifecycleObserverSpy: LifecycleObserverProtocol {
    private var listeners: [(listener: any LifecycleListener, events: Set<LifecycleEvent>)] = []

    var registrationCount: Int { listeners.count }

    func registeredEvents() -> [Set<LifecycleEvent>] {
        listeners.map(\.events)
    }

    func registerListener(_ listener: LifecycleListener, for events: Set<LifecycleEvent>) {
        listeners.removeAll { $0.listener === listener }
        listeners.append((listener, events))
    }

    /// Delivers `event` to every listener registered for it, awaiting each in turn.
    func fire(_ event: LifecycleEvent) async {
        for entry in listeners where entry.events.contains(event) {
            await entry.listener.handleLifecycleEvent(event)
        }
    }
}
