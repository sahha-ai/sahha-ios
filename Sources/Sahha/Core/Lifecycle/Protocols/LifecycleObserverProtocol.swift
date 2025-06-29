protocol LifecycleObserverProtocol: Actor, DisposableAsync {
    func addHandler(_ handler: LifecycleHandler, for events: Set<LifecycleEvent>)
    func removeHandler(_ handler: LifecycleHandler)
}
