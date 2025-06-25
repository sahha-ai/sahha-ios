protocol LifecycleHandler: AnyObject, Sendable {
    func handleLifecycleEvent(event: LifecycleEvent) async
}
