import Foundation

protocol LifecycleObserving: Actor {
    func registerListener(_ listener: LifecycleListener, for events: Set<LifecycleEvent>, queue: OperationQueue?)
}

extension LifecycleObserving {
    func registerListener(_ listener: LifecycleListener) {
        registerListener(
            listener,
            for: Set(LifecycleEvent.allCases),
            queue: LifecycleQueues.default
        )
    }

    func registerListener(_ listener: LifecycleListener, for events: Set<LifecycleEvent>) {
        registerListener(
            listener,
            for: events,
            queue: LifecycleQueues.default
        )
    }

    func registerListener(_ listener: LifecycleListener, queue: OperationQueue?) {
        registerListener(
            listener,
            for: Set(LifecycleEvent.allCases),
            queue: queue
        )
    }
}
