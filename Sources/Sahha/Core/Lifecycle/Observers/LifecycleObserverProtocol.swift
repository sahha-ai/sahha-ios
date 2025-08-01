import Foundation

protocol LifecycleObserverProtocol: Actor {
    func registerListener(_ listener: LifecycleListener, for events: Set<LifecycleEvent>)
}

extension LifecycleObserverProtocol {
    func registerListener(_ listener: LifecycleListener, for events: Set<LifecycleEvent> = Set(LifecycleEvent.allCases)) {
        registerListener(
            listener,
            for: events,
            
        )
    }
}
