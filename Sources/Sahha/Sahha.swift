import Foundation
import UIKit
import BackgroundTasks

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

    /// Controls whether internal SDK logs are logged. Off by default.
    nonisolated(unsafe) static var debugLogging = false


    static func log(_ message: @autoclosure () -> String) {
        guard debugLogging else { return }
        print(message())
    }

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
                Sahha.log("[\(SDK.name)] ERROR: Failed to configure Sahha: \(error.localizedDescription)")
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
                Sahha.log("[\(SDK.name)] Failed to handle background session events: \(error)")
                completionHandler()
            }
        }
    }
    
    // MARK: - Background App Refresh
    
    /// Stored identifier for auto-scheduling background tasks
    nonisolated(unsafe) private static var backgroundTaskIdentifier: String?
    nonisolated(unsafe) private static var backgroundObserver: NSObjectProtocol?
    
    /// Enables automatic background refresh for reliable data collection.
    /// This registers the task and automatically schedules refreshes when the app enters background.
    /// Call this in `application(_:didFinishLaunchingWithOptions:)`.
    /// - Parameter identifier: The identifier for the background task (must match Info.plist)
    public static func enableBackgroundRefresh(identifier: String) {
        backgroundTaskIdentifier = identifier
        
        // Register the background task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            handleBackgroundRefreshTask(task)
        }
        
        // Auto-schedule when app enters background
        if backgroundObserver == nil {
            backgroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { _ in
                scheduleBackgroundRefreshIfNeeded()
            }
        }
        
        Sahha.log("[\(SDK.name)] Background refresh enabled with identifier: \(identifier)")
    }
    
    /// Legacy method - registers a background app refresh task.
    /// Prefer `enableBackgroundRefresh(identifier:)` for automatic scheduling.
    /// - Parameter identifier: The identifier for the background task (must match Info.plist)
    public static func registerBackgroundRefreshTask(identifier: String) {
        enableBackgroundRefresh(identifier: identifier)
    }
    
    /// Schedules the next background app refresh.
    /// - Parameters:
    ///   - identifier: The identifier for the background task
    ///   - timeInterval: The minimum time interval (in seconds) to wait before the task runs (default: 15 minutes)
    public static func scheduleBackgroundRefreshTask(identifier: String, timeInterval: TimeInterval = 900) {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: timeInterval)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            Sahha.log("[\(SDK.name)] Scheduled background refresh for \(Int(timeInterval/60)) minutes from now")
        } catch {
            Sahha.log("[\(SDK.name)] Failed to schedule background refresh: \(error)")
        }
    }
    
    /// Internal method to schedule refresh using stored identifier
    internal static func scheduleBackgroundRefreshIfNeeded(timeInterval: TimeInterval = 900) {
        guard let identifier = backgroundTaskIdentifier else {
            return // Background refresh not enabled
        }
        scheduleBackgroundRefreshTask(identifier: identifier, timeInterval: timeInterval)
    }
    
    private static func handleBackgroundRefreshTask(_ task: BGAppRefreshTask) {
        Sahha.log("[\(SDK.name)] Background refresh task started")
        
        // Schedule the next refresh immediately (before doing work)
        scheduleBackgroundRefreshTask(identifier: task.identifier)
        
        task.expirationHandler = {
            Sahha.log("[\(SDK.name)] Background refresh task expiring")
            // The system is killing the task.
            // postSensorData doesn't currently support explicit cancellation,
            // but the process termination will stop it.
        }
        
        let sendableTask = SendableBGTask(task: task)
        
        // Perform the data sync
        postSensorData { result in
            // Mark task as completed with actual success status
            let success = result.failedSensors == 0 && result.errorDescription == nil
            Sahha.log("[\(SDK.name)] Background refresh task completed (success: \(success))")
            sendableTask.task.setTaskCompleted(success: success)
        }
    }

    // Wrapper to allow passing BGTask to Sendable closure
    private struct SendableBGTask: @unchecked Sendable {
        let task: BGTask
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
                Sahha.log("Failed to open app settings: Invalid or unsupported settings URL.")
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
                // Log error through the SDK's error logger (respects environment filtering)
                await actor.logError(error)
                
                let sahhaError = SahhaError.from(error)
                DispatchQueue.main.async {
                    box.callback(sahhaError.localizedDescription, defaultErrorValue())
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
                // Log error through the SDK's error logger (respects environment filtering)
                await actor.logError(error)
                
                let sahhaError = SahhaError.from(error)
                DispatchQueue.main.async {
                    box.callback(sahhaError.localizedDescription, defaultErrorValue())
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
        Sahha.log("[PostSensorData] Timestamp: \(result.timestamp)")
        if let error = result.errorDescription {
            Sahha.log("  Error: \(error)")
        }
        Sahha.log("  Sensors Queried: \(result.totalSensors)")
        Sahha.log("  Samples Fetched: \(result.totalSamples)")
        Sahha.log("  Logs Produced: \(result.totalLogs)")
        Sahha.log("  Success: \(result.successfulSensors) | Failed: \(result.failedSensors) | Skipped: \(result.skippedSensors)")
    }
}
