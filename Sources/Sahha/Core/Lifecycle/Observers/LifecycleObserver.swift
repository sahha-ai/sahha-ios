import Foundation

protocol LifecycleObserver: Actor {
    func registerListener(_ listener: LifecycleListener, for events: Set<LifecycleEvent>, queue: OperationQueue?)
}
