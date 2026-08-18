/// Minimal pre-auth lifecycle listener for the deferred bring-up retry (PRD #76
/// D10): it forwards resume, foreground, and unlock events to the actor's
/// trigger handler and holds no other state. Registered on every configure —
/// before the auth gate, so a deferred verdict has its triggers in place with
/// no gap — and held strongly by the actor, because `LifecycleObserver` holds
/// listeners weakly.
final class BringUpRetryLifecycleListener: LifecycleListener {
    private let onTrigger: @Sendable (LifecycleEvent) async -> Void

    init(onTrigger: @escaping @Sendable (LifecycleEvent) async -> Void) {
        self.onTrigger = onTrigger
    }

    func handleLifecycleEvent(_ event: LifecycleEvent) async {
        await onTrigger(event)
    }
}
