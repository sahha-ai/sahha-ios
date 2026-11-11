import UIKit

/// A UIKit background task that ends exactly once: when the work calls `end()`,
/// or from the expiration handler if the app's background time runs out first.
///
/// UIKit terminates an app that still holds a background task when its
/// background time runs out, so the expiration handler has to end the task
/// itself, synchronously, before it returns. The lease is main-actor isolated
/// because that is where both ends happen: UIKit calls the expiration handler
/// synchronously on the main thread, so it and `end()` can never interleave,
/// and whichever runs second finds the task already ended.
@MainActor
final class BackgroundTaskLease {
    private let name: String
    private let provider: BackgroundTaskProviding
    private var onEnd: (@Sendable () -> Void)?
    private var identifier: UIBackgroundTaskIdentifier = .invalid
    private var isEnded = false

    private init(name: String, provider: BackgroundTaskProviding, onEnd: (@Sendable () -> Void)?) {
        self.name = name
        self.provider = provider
        self.onEnd = onEnd
    }

    /// Begins a background task named `name`.
    ///
    /// - Parameter onEnd: Runs once, immediately before the task ends, whether
    ///   `end()` or the expiration handler ends it.
    static func begin(
        named name: String,
        provider: BackgroundTaskProviding,
        onEnd: (@Sendable () -> Void)? = nil
    ) -> BackgroundTaskLease {
        let lease = BackgroundTaskLease(name: name, provider: provider, onEnd: onEnd)
        let identifier = provider.beginBackgroundTask(withName: name) {
            lease.expire()
        }
        lease.attach(identifier)
        return lease
    }

    /// Runs `onEnd` and ends the task, unless the task has already ended.
    func end() {
        guard !isEnded else { return }
        isEnded = true
        let onEnd = self.onEnd
        self.onEnd = nil
        onEnd?()
        if identifier != .invalid {
            provider.endBackgroundTask(identifier)
            identifier = .invalid
        }
    }

    private func expire() {
        guard !isEnded else { return }
        Sahha.log("[BackgroundTask] \(name) ran out of background time; ending it")
        end()
    }

    /// Stores the identifier `beginBackgroundTask` returned. If the expiration
    /// handler already ran inside that call, before any identifier existed to
    /// end, the task is ended here instead.
    private func attach(_ identifier: UIBackgroundTaskIdentifier) {
        guard identifier != .invalid else { return }
        if isEnded {
            provider.endBackgroundTask(identifier)
        } else {
            self.identifier = identifier
        }
    }
}
