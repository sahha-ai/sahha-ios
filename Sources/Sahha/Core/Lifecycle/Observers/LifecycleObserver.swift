import Foundation
import UIKit

final actor LifecycleObserver: LifecycleObserving {
    private struct Listener {
        weak var ref: LifecycleListener?
        let events: Set<LifecycleEvent>
    }

    private var listeners: [Listener] = []
    private var observers: [LifecycleEvent: NSObjectProtocol] = [:]  // keeps NC tokens

    /// Register `listener` for `events` (default = all).
    func registerListener(
        _ listener: LifecycleListener,
        for events: Set<LifecycleEvent> = .init(LifecycleEvent.allCases),
        queue: OperationQueue? = LifecycleQueues.default
    ) {
        // De-dup & purge dead boxes …
        listeners.removeAll { $0.ref == nil || $0.ref === listener }
        listeners.append(Listener(ref: listener, events: events))

        // Lazily attach NotificationCenter observers
        for event in events { ensureObserver(for: event, queue: queue) }
    }

    private func ensureObserver(for event: LifecycleEvent, queue: OperationQueue?) {
        guard observers[event] == nil, let name = event.notification else { return }

        let observer = NotificationCenter.default.addObserver(
            forName: name,
            object: nil,
            queue: queue
        ) { [weak self] _ in
            Task { await self?.broadcast(event) }
        }
        observers[event] = observer
    }

    private func cleanupListeners() {
        listeners.removeAll { $0.ref == nil }
    }

    private func cleanupObservers() {
        let toRemove = observers.keys.filter { event in
            !listeners.contains { $0.events.contains(event) }
        }

        for event in toRemove {
            if let token = observers.removeValue(forKey: event) {
                NotificationCenter.default.removeObserver(token)
            }
        }
    }

    private func broadcast(_ event: LifecycleEvent) {
        cleanupListeners()
        cleanupObservers()

        for listener in listeners where listener.events.contains(event) {
            if let ref = listener.ref {
                Task { await ref.handleLifecycleEvent(event) }
            }
        }
    }
}
