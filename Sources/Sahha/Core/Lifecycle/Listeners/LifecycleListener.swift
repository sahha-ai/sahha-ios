protocol LifecycleListener: AnyObject, Sendable {
    func handleLifecycleEvent(_ event: LifecycleEvent) async
}
