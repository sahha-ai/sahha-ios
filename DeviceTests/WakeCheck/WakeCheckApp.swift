import CryptoKit
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
        WakeLog.shared.flushBeforeExit()
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
    /// The environment and app (a hash of its ID) the current session was signed in with.
    private static let signedInWithKey = "wakecheck.signedInWith"

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

        guard !appId.isEmpty, !appSecret.isEmpty else {
            // Any launch but an install's: start the SDK with the session it has.
            configure(environment, name: name, signIn: nil)
            return
        }

        // An install's launch. A session signed in with other settings (another
        // environment or app), or with unknown ones, is signed out first, before the SDK
        // starts, so nothing is collected or sent with it. Signing out needs no configure.
        let settings = "\(name)|\(fingerprint(of: appId))"
        let signIn = SignIn(appId: appId, appSecret: appSecret, settings: settings)
        guard Sahha.isAuthenticated,
              UserDefaults.standard.string(forKey: signedInWithKey) != settings else {
            configure(environment, name: name, signIn: signIn)
            return
        }
        WakeLog.shared.record("install settings differ from the current session's: signing out first")
        Sahha.deauthenticate { error, success in
            guard success, !Sahha.isAuthenticated else {
                WakeLog.shared.record("sign-out failed, so the SDK isn't started: \(error ?? "no error given")")
                return
            }
            signedOut()
            WakeLog.shared.record("signed out of the previous session")
            configure(environment, name: name, signIn: signIn)
        }
    }

    /// Forgets which settings the session was signed in with, after a sign-out.
    static func signedOut() {
        UserDefaults.standard.removeObject(forKey: signedInWithKey)
    }

    private struct SignIn {
        let appId: String
        let appSecret: String
        let settings: String
    }

    private static func configure(_ environment: SahhaEnvironment, name: String, signIn: SignIn?) {
        Sahha.configure(SahhaSettings(environment: environment)) {
            WakeLog.shared.record("configured for \(name), signed in: \(Sahha.isAuthenticated)")
            guard let signIn, !Sahha.isAuthenticated else { return }
            Sahha.authenticate(appId: signIn.appId, appSecret: signIn.appSecret, externalId: externalId) { error, success in
                if success {
                    UserDefaults.standard.set(signIn.settings, forKey: signedInWithKey)
                }
                WakeLog.shared.record(success
                    ? "signed in as \(externalId)"
                    : "sign-in failed: \(error ?? "no error given")")
            }
        }
    }

    /// Enough of the app ID to tell two apart, without keeping the ID itself.
    private static func fingerprint(of appId: String) -> String {
        SHA256.hash(data: Data(appId.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}

private struct UncheckedCompletion: @unchecked Sendable {
    let run: () -> Void
}
