protocol LifecycleObserverProtocol: Actor {
    func addHandler(_ handler: LifecycleHandler, for events: Set<LifecycleEvent>)
    func removeHandler(_ handler: LifecycleHandler)
}
