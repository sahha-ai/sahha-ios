import Foundation
import UIKit

/// Synchronous auth for legacy API - updated from TokenStore
final class AuthSnapshot: @unchecked Sendable {
    var profileToken: String?
    var isAuthenticated: Bool {
        guard let profileToken else { return false }
        return !profileToken.isEmpty
    }
}

public class Sahha {
    private static let actor: SahhaActor = .shared
    static let authSnapshot = AuthSnapshot()

    // MARK: - Configuration
    public static func configure(_ settings: SahhaSettings, callback: (() -> Void)? = nil) {
        let box = VoidCallbackBox(callback: callback)
        Task {
            do {
                try await actor.configure(with: settings)
                DispatchQueue.main.async {
                    box.callback?()
                }
            } catch {
                print("[\(SDK.name)] ERROR: Failed to configure Sahha: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Authentication
    public static var isAuthenticated: Bool {
        authSnapshot.isAuthenticated
    }

    public static var profileToken: String? {
        authSnapshot.profileToken
    }

    public static func authenticate(appId: String, appSecret: String, externalId: String, callback: @escaping (String?, Bool) -> Void) {
        runAsyncWithCallback(
            callback: callback,
            task: {
                let authManager = try await actor.authManager()
                try await authManager.authenticate(appId: appId, appSecret: appSecret, externalId: externalId)
                try await actor.startAuthenticatedServices()
                return true
            },
            defaultErrorValue: false
        )
    }

    public static func authenticate(profileToken: String, refreshToken: String, callback: @escaping (String?, Bool) -> Void) {
        runAsyncWithCallback(
            callback: callback,
            task: {
                let authManager = try await actor.authManager()
                try await authManager.authenticate(profileToken: profileToken, refreshToken: refreshToken)
                try await actor.startAuthenticatedServices()
                return true
            },
            defaultErrorValue: false
        )
    }

    public static func deauthenticate(callback: @escaping (String?, Bool) -> Void) {
        runAsyncWithCallback(
            callback: callback,
            requiresAuth: true,
            task: {
                try await actor.deauthenticate()
                return true
            },
            defaultErrorValue: false
        )
    }

    // MARK: - Demographic
    public static func getDemographic(callback: @escaping (String?, SahhaDemographic?) -> Void) {
        runAsyncWithCallback(
            callback: callback,
            requiresAuth: true,
            task: {
                let demographicManager = try await actor.demographicManager()
                return try await demographicManager.getDemographic()
            }
        )
    }

    public static func postDemographic(_ demographic: SahhaDemographic, callback: @escaping (String?, Bool) -> Void) {
        runAsyncWithCallback(
            callback: callback,
            requiresAuth: true,
            task: {
                let demographicManager = try await actor.demographicManager()
                try await demographicManager.updateDemographic(demographic)
                return true
            },
            defaultErrorValue: false
        )
    }

    // MARK: - Sensors
    public static func getSensorStatus(_ sensors: Set<SahhaSensor>, callback: @escaping (String?, SahhaSensorStatus) -> Void) {
        runAsyncWithCallback(
            callback: callback,
            task: {
                let healthKitManager = try await actor.healthKitManager()
                return try await healthKitManager.getSensorStatus(sensors)
            },
            defaultErrorValue: .pending
        )
    }

    public static func enableSensors(_ sensors: Set<SahhaSensor>, callback: @escaping (String?, SahhaSensorStatus) -> Void) {
        runAsyncWithCallback(
            callback: callback,
            requiresAuth: true,
            task: {
                let healthKitManager = try await actor.healthKitManager()
                try await healthKitManager.enableSensors(sensors)
                return try await healthKitManager.getSensorStatus(sensors)
            },
            defaultErrorValue: .pending
        )
    }

    public static func postSensorData(
        debug: Bool = false,
        callback: (@Sendable (PostSensorDataResult) -> Void)? = nil
    ) {
        Task {
            do {
                let healthKitManager = try await actor.healthKitManager()
                let result = await healthKitManager.querySensors()
                if debug {
                    logPostSensorData(result)
                }
                if let callback {
                    await MainActor.run {
                        callback(result)
                    }
                }
            } catch {
                let result = PostSensorDataResult.failure(error)
                if debug {
                    logPostSensorData(result)
                }
                if let callback {
                    await MainActor.run {
                        callback(result)
                    }
                }
            }
        }
    }
    
    // MARK: - Background Upload Support
    
    /// Handle background URLSession completion events
    /// Call this from your AppDelegate's `application(_:handleEventsForBackgroundURLSession:completionHandler:)`
    /// - Parameters:
    ///   - identifier: The session identifier from the system callback
    ///   - completionHandler: The completion handler to call when all background tasks are done
    public static func handleBackgroundSessionEvents(
        identifier: String,
        completionHandler: @escaping @Sendable () -> Void
    ) {
        Task {
            do {
                let delegate = try await actor.backgroundDelegate()
                delegate.setCompletionHandler(completionHandler, for: identifier)
            } catch {
                print("[\(SDK.name)] Failed to handle background session events: \(error)")
                completionHandler()
            }
        }
    }

    // MARK: - Samples
    public static func getSamples(sensor: SahhaSensor, startDateTime: Date, endDateTime: Date, callback: @escaping (String?, [SahhaSample]) -> Void) {
        runAsyncWithCallback(
            callback: callback,
            task: {
                let healthKitManager = try await actor.healthKitManager()
                return try await healthKitManager.getSamples(
                    for: sensor,
                    startDateTime: startDateTime,
                    endDateTime: endDateTime
                )
            },
            defaultErrorValue: []
        )
    }

    // MARK: - Stats
    public static func getStats(sensor: SahhaSensor, startDateTime: Date, endDateTime: Date, callback: @escaping (String?, [SahhaStat]) -> Void) {
        runAsyncWithCallback(
            callback: callback,
            task: {
                let healthKitManager = try await actor.healthKitManager()
                return try await healthKitManager.getStats(
                    for: sensor,
                    startDateTime: startDateTime,
                    endDateTime: endDateTime
                )
            },
            defaultErrorValue: []
        )
    }

    // MARK: - Scores
    public static func getScores(types: Set<SahhaScoreType>, startDateTime: Date, endDateTime: Date, callback: @escaping (String?, String?) -> Void) {
        runAsyncWithCallback(
            callback: callback,
            requiresAuth: true,
            task: {
                let scoreManager = try await actor.scoreManager()
                return try await scoreManager.getScores(types: types, startDateTime: startDateTime, endDateTime: endDateTime)
            }
        )
    }

    // MARK: - Biomarkers
    public static func getBiomarkers(
        categories: Set<SahhaBiomarkerCategory>,
        types: Set<SahhaBiomarkerType>,
        startDateTime: Date,
        endDateTime: Date,
        callback: @escaping (String?, String?) -> Void
    ) {
        runAsyncWithCallback(
            callback: callback,
            requiresAuth: true,
            task: {
                let biomarkerManager = try await actor.biomarkerManager()
                return try await biomarkerManager.getBiomarkers(
                    categories: categories,
                    types: types,
                    startDateTime: startDateTime,
                    endDateTime: endDateTime
                )
            }
        )
    }

    // MARK: - Settings
    public static func openAppSettings() {
        Task { @MainActor in
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString),
                UIApplication.shared.canOpenURL(settingsURL)
            else {
                print("Failed to open app settings: Invalid or unsupported settings URL.")
                return
            }
            await UIApplication.shared.open(settingsURL)
        }
    }

    // MARK: - Errors
    public static func postError(framework: SahhaFramework = .ios_swift, message: String, path: String, method: String, body: String) {
        Task {
            await actor.postError(framework: framework, message: message, path: path, method: method, body: body)
        }
    }

    // MARK: - Private Helpers

    /// Legacy support for completion handler APIs
    private struct VoidCallbackBox: @unchecked Sendable {
        let callback: (() -> Void)?
    }
    
    /// Legacy support for completion handler APIs
    private struct CallbackBox<T, K>: @unchecked Sendable {
        let callback: (T, K) -> Void
    }

    /// Helper for async APIs that return a non-optional result via completion handler.
    private static func runAsyncWithCallback<T>(
        callback: @escaping (String?, T) -> Void,
        requiresAuth: Bool = false,
        task: @escaping @Sendable () async throws -> T,
        defaultErrorValue: @autoclosure @escaping @Sendable () -> T
    ) {
        let box = CallbackBox(callback: callback)
        Task {
            do {
                if requiresAuth { try authGuard() }
                let result = try await task()
                DispatchQueue.main.async {
                    box.callback(nil, result)
                }
            } catch {
                let error = SahhaError.from(error)
                DispatchQueue.main.async {
                    box.callback(error.localizedDescription, defaultErrorValue())
                }
            }
        }
    }

    /// Helper for async APIs that return an optional result via completion handler.
    private static func runAsyncWithCallback<T>(
        callback: @escaping (String?, T?) -> Void,
        requiresAuth: Bool = false,
        task: @escaping @Sendable () async throws -> T,
        defaultErrorValue: @autoclosure @escaping @Sendable () -> T? = nil
    ) {
        let box = CallbackBox(callback: callback)
        Task {
            do {
                if requiresAuth { try authGuard() }
                let result = try await task()
                DispatchQueue.main.async {
                    box.callback(nil, result)
                }
            } catch {
                let error = SahhaError.from(error)
                DispatchQueue.main.async {
                    box.callback(error.localizedDescription, defaultErrorValue())
                }
            }
        }
    }
    
    private static func authGuard() throws {
        if !isAuthenticated {
            throw SahhaError(message: "Unauthorized. Please call `Sahha.authenticate(...)` first.")
        }
    }

    private static func logPostSensorData(_ result: PostSensorDataResult) {
        print("[PostSensorData] Timestamp: \(result.timestamp)")
        if let error = result.errorDescription {
            print("  Error: \(error)")
        }
        print("  Sensors Queried: \(result.totalSensors)")
        print("  Samples Fetched: \(result.totalSamples)")
        print("  Logs Produced: \(result.totalLogs)")
        print("  Success: \(result.successfulSensors) | Failed: \(result.failedSensors) | Skipped: \(result.skippedSensors)")
    }
}
