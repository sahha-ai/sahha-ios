import UIKit

/// The app's state at one moment, as reported in diagnostics.
struct ApplicationStateSnapshot: Sendable, Equatable, CustomStringConvertible {
    /// "active", "inactive" or "background".
    let state: String
    let isProtectedDataAvailable: Bool
    /// Seconds of background execution left; nil unless the app is in the background.
    let backgroundTimeRemaining: TimeInterval?

    var description: String {
        var text = "\(state), protectedData: \(isProtectedDataAvailable ? "available" : "unavailable")"
        if let backgroundTimeRemaining {
            text += ", backgroundTimeRemaining: \(String(format: "%.1f", backgroundTimeRemaining))s"
        }
        return text
    }
}

protocol ApplicationStateProviding: Sendable {
    func snapshot() async -> ApplicationStateSnapshot
}

/// Reads the live state from `UIApplication` on the main actor.
struct UIKitApplicationStateProvider: ApplicationStateProviding {
    func snapshot() async -> ApplicationStateSnapshot {
        await MainActor.run {
            let application = UIApplication.shared
            let state: String
            switch application.applicationState {
            case .active: state = "active"
            case .inactive: state = "inactive"
            case .background: state = "background"
            @unknown default: state = "unknown"
            }
            // Reported only in the background: in the foreground the value is
            // effectively infinite.
            let remaining = application.backgroundTimeRemaining
            let isBackground = application.applicationState == .background
            return ApplicationStateSnapshot(
                state: state,
                isProtectedDataAvailable: application.isProtectedDataAvailable,
                backgroundTimeRemaining: isBackground && remaining < 1_000_000 ? remaining : nil
            )
        }
    }
}
