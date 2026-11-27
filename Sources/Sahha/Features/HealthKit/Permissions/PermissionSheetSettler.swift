import UIKit

/// Waits until the screen can take a HealthKit permission sheet.
///
/// HealthKit presents its sheet on the app's topmost presented view controller, and it
/// calls a request's completion while that request's sheet is still animating away
/// (about half a second on iOS 27). A request made in that window picks the dismissing
/// sheet as its presenter: UIKit refuses ("Attempt to present … whose view is not in the
/// window hierarchy"), no sheet appears, and HealthKit never calls the completion, so the
/// request can only time out. A modal presentation or dismissal of the host app's own,
/// still in flight, breaks a sheet the same way.
protocol PermissionSheetSettling: Sendable {
    /// Returns once no view controller is being presented or dismissed and no Health
    /// permission sheet is on screen, or once the wait gives up. Returns whether the
    /// screen settled.
    @discardableResult
    func waitUntilSettled() async -> Bool
}

/// Polls the app's presentation chains on the main actor until they settle.
struct PermissionSheetSettler: PermissionSheetSettling {
    /// A dismissal takes about half a second. The cap only matters when something else
    /// keeps the screen busy (a sheet the host app requested and the user is still
    /// reading, or a transition that never ends), and past it the request goes ahead,
    /// exactly as it would have without the wait.
    static let defaultTimeout: TimeInterval = 5
    static let defaultPollInterval: TimeInterval = 0.05

    private let timeout: TimeInterval
    private let pollInterval: TimeInterval
    private let isSettled: @MainActor @Sendable () -> Bool

    init(
        timeout: TimeInterval = PermissionSheetSettler.defaultTimeout,
        pollInterval: TimeInterval = PermissionSheetSettler.defaultPollInterval,
        isSettled: @escaping @MainActor @Sendable () -> Bool = { PermissionSheetSettler.isSettled(PermissionSheetSettler.currentChains()) }
    ) {
        self.timeout = timeout
        self.pollInterval = pollInterval
        self.isSettled = isSettled
    }

    @discardableResult
    func waitUntilSettled() async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            if await isSettled() { return true }
            // Cancellation ends the wait rather than the request: the caller decides
            // what a cancelled request means, as it did before this wait existed.
            guard Date() < deadline, !Task.isCancelled else { return false }
            try? await Task.sleep(nanoseconds: UInt64(max(pollInterval, 0.001) * 1_000_000_000))
        }
    }

    // MARK: - Reading the screen

    /// One view controller in a window's presentation chain, reduced to what decides
    /// whether HealthKit can present on top of it.
    struct Link: Equatable, Sendable {
        /// Being presented or being dismissed.
        let isTransitioning: Bool
        /// HealthKit's own permission sheet.
        let isHealthPermissionSheet: Bool
    }

    /// Settled means nothing in any chain is mid-transition and no Health permission
    /// sheet is still up. The second half matters when HealthKit calls back before its
    /// sheet has started to dismiss: the sheet is then still presented, not yet
    /// transitioning, and a new request would be presented on it once it starts to go.
    static func isSettled(_ chains: [[Link]]) -> Bool {
        !chains.joined().contains { $0.isTransitioning || $0.isHealthPermissionSheet }
    }

    /// Every window's chain from its root view controller up through each presented one.
    /// Empty outside an app (a hostless test bundle has no shared application).
    @MainActor
    static func currentChains() -> [[Link]] {
        // `UIApplication.shared` is nil in a process with no UIApplication, where the
        // Swift accessor cannot be called safely; the key-value lookup returns nil.
        guard let application = UIApplication.value(forKey: "sharedApplication") as? UIApplication else {
            return []
        }
        return application.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .map { window in
                var chain: [Link] = []
                var controller = window.rootViewController
                while let current = controller {
                    chain.append(Link(
                        isTransitioning: current.isBeingPresented || current.isBeingDismissed,
                        isHealthPermissionSheet: isHealthPermissionSheet(current)
                    ))
                    controller = current.presentedViewController
                }
                return chain
            }
    }

    /// HealthKit's sheet is a private class (HKHealthPrivacyHostAuthorizationViewController
    /// in HealthUI on iOS 27), so it is recognised by its framework or, should it move,
    /// by its name.
    @MainActor
    static func isHealthPermissionSheet(_ controller: UIViewController) -> Bool {
        let type: AnyClass = Swift.type(of: controller)
        if Bundle(for: type).bundleIdentifier?.hasPrefix("com.apple.Health") == true { return true }
        return NSStringFromClass(type).hasPrefix("HKHealthPrivacy")
    }
}
