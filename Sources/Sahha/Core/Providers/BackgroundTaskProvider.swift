import UIKit

/// The UIKit background-task calls the SDK makes, behind a seam so tests can
/// fire a task's expiration handler.
protocol BackgroundTaskProviding: Sendable {
    /// Begins a background task. UIKit calls `expirationHandler` on the main
    /// thread shortly before the app's background time runs out.
    @MainActor
    func beginBackgroundTask(
        withName name: String,
        expirationHandler: @escaping @MainActor @Sendable () -> Void
    ) -> UIBackgroundTaskIdentifier

    @MainActor
    func endBackgroundTask(_ identifier: UIBackgroundTaskIdentifier)
}

/// Forwards to `UIApplication.shared`.
struct UIKitBackgroundTaskProvider: BackgroundTaskProviding {
    @MainActor
    func beginBackgroundTask(
        withName name: String,
        expirationHandler: @escaping @MainActor @Sendable () -> Void
    ) -> UIBackgroundTaskIdentifier {
        UIApplication.shared.beginBackgroundTask(withName: name) {
            expirationHandler()
        }
    }

    @MainActor
    func endBackgroundTask(_ identifier: UIBackgroundTaskIdentifier) {
        UIApplication.shared.endBackgroundTask(identifier)
    }
}
