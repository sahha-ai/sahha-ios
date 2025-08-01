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
                let manager = try await actor.demographicManager()
                return try await manager.getDemographic()
            }
        )
    }

    public static func postDemographic(_ demographic: SahhaDemographic, callback: @escaping (String?, Bool) -> Void) {
        runAsyncWithCallback(
            callback: callback,
            requiresAuth: true,
            task: {
                let manager = try await actor.demographicManager()
                try await manager.updateDemographic(demographic)
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
                let manager = try await actor.healthKitManager()
                return try await manager.getSensorStatus(sensors)
            },
            defaultErrorValue: .pending
        )
    }

    public static func enableSensors(_ sensors: Set<SahhaSensor>, callback: @escaping (String?, SahhaSensorStatus) -> Void) {
        runAsyncWithCallback(
            callback: callback,
            requiresAuth: true,
            task: {
                let manager = try await actor.healthKitManager()
                try await manager.enableSensors(sensors)
                return try await manager.getSensorStatus(sensors)
            },
            defaultErrorValue: .pending
        )
    }

    public static func postSensorData() {
        Task {
            do {
                let healthKitManager = try await actor.healthKitManager()
                await healthKitManager.querySensors()
            } catch {
                // Currently just fails silently
            }
        }
    }

    // MARK: - Samples
    public static func getSamples(sensor: SahhaSensor, startDateTime: Date, endDateTime: Date, callback: @escaping (String?, [SahhaSample]) -> Void) {
        runAsyncWithCallback(
            callback: callback,
            task: {
                let manager = try await actor.healthKitManager()
                return try await manager.getSamples(
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
                let manager = try await actor.healthKitManager()
                return try await manager.getStats(
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
                let manager = try await actor.scoreManager()
                return try await manager.getScores(types: types, startDateTime: startDateTime, endDateTime: endDateTime)
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
                let manager = try await actor.biomarkerManager()
                return try await manager.getBiomarkers(
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
}
