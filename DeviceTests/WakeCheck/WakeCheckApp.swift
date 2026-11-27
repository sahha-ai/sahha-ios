import SwiftUI
import UIKit
// Only for `Sahha.debugLogging`, which is internal. Everything else here is public API,
// used the way a customer's app uses it.
@testable import Sahha

/// A minimal host app for the background checks in MANUAL_CHECKLIST.md: does iOS wake the
/// app for new health data, and does the SDK upload it before anyone opens the app?
///
/// It starts the SDK at every launch, foreground or background, and writes a timestamped
/// timeline of its own events and the SDK's debug log to `Documents/wake-check.log`.
/// `DeviceTests/wake-check.sh` installs it, signs it in, and reads the timeline back.
@main
struct WakeCheckApp: App {
    @UIApplicationDelegateAdaptor(WakeCheckAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            WakeCheckView()
        }
    }
}

final class WakeCheckAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let log = WakeLog.shared
        log.startCapturingStdout()
        let options = launchOptions?.keys.map(\.rawValue).sorted() ?? []
        // Whether the user or iOS launched the app shows in the timeline: a user launch is
        // followed within a second by "opened". `applicationState` can't tell them apart
        // here, because a SwiftUI app reports background until its scene connects.
        log.record("launch (pid \(getpid())\(options.isEmpty ? "" : ", options: \(options)"))")
        observeLifecycle()

        Sahha.debugLogging = true
        WakeCheckSession.start()
        return true
    }

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        WakeLog.shared.record("background upload session events: \(identifier)")
        // UIKit's handler isn't marked Sendable; it may be called from any thread.
        let completion = UncheckedCompletion(run: completionHandler)
        Sahha.handleBackgroundSessionEvents(identifier: identifier) { completion.run() }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        WakeLog.shared.record("will terminate")
        WakeLog.shared.flush()
    }

    private func observeLifecycle() {
        let events: [(Notification.Name, String)] = [
            (UIApplication.didBecomeActiveNotification, "opened"),
            (UIApplication.didEnterBackgroundNotification, "left the foreground"),
            (UIApplication.protectedDataWillBecomeUnavailableNotification, "phone locked"),
            (UIApplication.protectedDataDidBecomeAvailableNotification, "phone unlocked"),
        ]
        for (name, label) in events {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                WakeLog.shared.record(label)
            }
        }
    }
}

/// The SDK set-up a host app runs at launch, plus a one-off sign-in.
enum WakeCheckSession {
    static let externalId = "sahha-ios-wake-check"
    static let sensors: Set<SahhaSensor> = [.steps, .heart_rate]

    private static let environmentKey = "wakecheck.environment"

    static var refreshTaskIdentifier: String {
        Bundle.main.object(forInfoDictionaryKey: "SahhaWakeCheckRefreshTask") as? String
            ?? "ai.sahha.sdk.wakecheck.refresh"
    }

    static var environmentName: String {
        UserDefaults.standard.string(forKey: environmentKey) ?? "not set"
    }

    /// Runs at every launch. Credentials arrive only on the launch `wake-check.sh install`
    /// makes, as environment variables; the SDK keeps the session in the keychain after
    /// that, and the environment's name is kept in user defaults.
    static func start() {
        let launch = ProcessInfo.processInfo.environment
        let appId = launch["SAHHA_APP_ID"] ?? ""
        let appSecret = launch["SAHHA_APP_SECRET"] ?? ""
        WakeLog.shared.redact([appId, appSecret])

        if let name = launch["SAHHA_ENVIRONMENT"], !name.isEmpty {
            UserDefaults.standard.set(name, forKey: environmentKey)
        }
        guard let name = UserDefaults.standard.string(forKey: environmentKey) else {
            WakeLog.shared.record("no environment set: install with DeviceTests/wake-check.sh install")
            return
        }
        guard let environment = SahhaEnvironment(rawValue: name), environment != .production else {
            WakeLog.shared.record("refusing environment \"\(name)\": use development or sandbox")
            return
        }

        // Registered before launch finishes, as BGTaskScheduler requires.
        Sahha.enableBackgroundRefresh(identifier: refreshTaskIdentifier)
        Sahha.configure(SahhaSettings(environment: environment)) {
            WakeLog.shared.record("configured for \(name), signed in: \(Sahha.isAuthenticated)")
            guard !Sahha.isAuthenticated, !appId.isEmpty, !appSecret.isEmpty else { return }
            Sahha.authenticate(appId: appId, appSecret: appSecret, externalId: externalId) { error, success in
                WakeLog.shared.record(success
                    ? "signed in as \(externalId)"
                    : "sign-in failed: \(error ?? "no error given")")
            }
        }
    }
}

private struct UncheckedCompletion: @unchecked Sendable {
    let run: () -> Void
}
