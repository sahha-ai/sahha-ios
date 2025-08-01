import Foundation
import UIKit

final actor LifecycleObserver: LifecycleObserverProtocol {
    private struct Listener {
        weak var ref: LifecycleListener?
        let events: Set<LifecycleEvent>
    }

    private var listeners: [Listener] = []

    init() {
        // Set up default queue
        let queue = OperationQueue()
        queue.name = "ai.sahha.lifecycleEventQueue"
        queue.qualityOfService = .utility
        queue.maxConcurrentOperationCount = 1
        // Eagerly set up NotificationCenter observers for ALL lifecycle events
        for event in LifecycleEvent.allCases {
            guard let name = event.notification else { continue }
            NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: queue
            ) { [weak self] _ in
                Task { await self?.broadcast(event) }
            }
        }
    }

    // MARK: - Listener Registration

    func registerListener(
        _ listener: LifecycleListener,
        for events: Set<LifecycleEvent>
    ) {
        // De-dup & purge dead boxes
        listeners.removeAll { $0.ref == nil || $0.ref === listener }
        listeners.append(Listener(ref: listener, events: events))
    }

    // MARK: - Clean Up Dead Listeners

    private func cleanupListeners() {
        listeners.removeAll { $0.ref == nil }
    }

    // MARK: - Broadcast Events

    private func broadcast(_ event: LifecycleEvent) {
        cleanupListeners()
        for listener in listeners where listener.events.contains(event) {
            if let ref = listener.ref {
                Task { await ref.handleLifecycleEvent(event) }
            }
        }
    }
}
