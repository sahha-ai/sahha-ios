import UIKit

/*:
 TODO:

 - Get stats / get samples
 - DataLog -> DataLogRequest
 - HealthKit errors

 */

public final class Sahha {
    private static let container: SahhaContainer = .shared

    @MainActor private static var _profileToken: String?
    @MainActor private static var _tokenExpiry: Date?

    // MARK: Configuration

    public static func configure(_ settings: SahhaSettings, callback: (@Sendable () -> Void)? = nil) {
        Task {
            do {
                try await container.configure(with: settings)

                if let tokenManager = try? await container.getTokenManager(),
                    let token = try? await tokenManager.ensureValidProfileToken(),
                    !token.isEmpty
                {
                    try await container.startAuthenticatedServices()
                }
            } catch {
                logError("Failed to configure Sahha", error: error)
            }
            callback?()
        }
    }

    // MARK: Authentication

    static func updateToken(token: String?, expiry: Date?) async {
        await MainActor.run {
            _profileToken = token
            _tokenExpiry = expiry
        }
    }

    @MainActor
    public static var isAuthenticated: Bool {
        _profileToken != nil && _profileToken?.isEmpty == false
    }

    @MainActor
    public static var profileToken: String? {
        _profileToken
    }

    public static func authenticate(appId: String, appSecret: String, externalId: String, callback: @escaping @Sendable (String?, Bool) -> Void) {
        Task {
            do {
                let authService = try await container.getAuthenticationService()
                let tokenManager = try await container.getTokenManager()
                let response = try await authService.registerProfile(appId: appId, appSecret: appSecret, externalId: externalId)
                try await tokenManager.saveToken(response)
                try await container.startAuthenticatedServices()
                callback(nil, true)
            } catch {
                logError("Failed to authenticate", error: error)
                callback(error.localizedDescription, false)
            }
        }
    }

    public static func authenticate(profileToken: String, refreshToken: String, callback: @escaping @Sendable (String?, Bool) -> Void) {
        Task {
            do {
                guard !profileToken.isEmpty else {
                    throw ValidationError.emptyString(field: "profileToken")
                }
                guard !refreshToken.isEmpty else {
                    throw ValidationError.emptyString(field: "refreshToken")
                }
                let tokenManager = try await container.getTokenManager()
                let tokenResponse = TokenResponse(profileToken: profileToken, refreshToken: refreshToken)
                try await tokenManager.saveToken(tokenResponse)
                try await container.startAuthenticatedServices()
                callback(nil, true)
            } catch {
                logError("Failed to authenticate", error: error)
                callback(error.localizedDescription, false)
            }
        }
    }

    public static func deauthenticate(callback: @escaping @Sendable (String?, Bool) -> Void) {
        Task {
            do {
                try await container.resetContainer()
                callback(nil, true)
            } catch {
                logError("Failed to deauthenticate", error: error)
                callback(error.localizedDescription, false)
            }
        }
    }

    // MARK: Demographic

    public static func getDemographic(callback: @escaping @Sendable (String?, SahhaDemographic?) -> Void) {
        Task {
            do {
                let demographicManager = try await container.getDemographicManager()
                let demographic = try await demographicManager.getDemographic()
                callback(nil, demographic)
            } catch {
                logError("Failed to get demographic", error: error)
                callback(error.localizedDescription, nil)
            }
        }
    }

    public static func postDemographic(_ demographic: SahhaDemographic, callback: @escaping @Sendable (String?, Bool) -> Void) {
        Task {
            do {
                let demographicService = try await container.getDemographicService()
                try await demographicService.updateDemographic(demographic)
                callback(nil, true)
            } catch {
                logError("Failed to post demographic", error: error)
                callback(error.localizedDescription, false)
            }
        }
    }

    // MARK: Sensors

    public static func enableSensors(_ sensors: Set<SahhaSensor>, callback: @escaping @Sendable (String?, SahhaSensorStatus) -> Void) {
        Task {
            do {
                guard !sensors.isEmpty else {
                    throw ValidationError.emptyCollection(collection: "sensors")
                }
                let sensorsManager = try await container.getSensorsManager()
                try await sensorsManager.enableSensors(sensors)
                let status = try await sensorsManager.getSensorStatus(sensors)
                callback(nil, status)
            } catch {
                logError("Error enabling sensors", error: error)
                callback(error.localizedDescription, .pending)
            }
        }
    }

    public static func getSensorStatus(_ sensors: Set<SahhaSensor>, callback: @escaping @Sendable (String?, SahhaSensorStatus) -> Void) {
        Task {
            do {
                guard !sensors.isEmpty else {
                    throw ValidationError.emptyCollection(collection: "sensors")
                }
                let sensorsManager = try await container.getSensorsManager()
                let status = try await sensorsManager.getSensorStatus(sensors)
                callback(nil, status)
            } catch {
                logError("Error getting sensor status", error: error)
                callback(error.localizedDescription, .pending)
            }
        }
    }

    // MARK: Samples

    // TODO: Create SahhaSample struct and get samples directly from hkManager
    public static func getSamples(
        sensor: SahhaSensor,
        startDateTime: Date,
        endDateTime: Date,
        callback: @escaping @Sendable (String?, [String]) -> Void
    ) {
        Task {
            do {
                guard startDateTime <= endDateTime else {
                    throw ValidationError.invalidDateRange
                }
                let hkManager = try await container.getHKManager()
                let samples = try await hkManager.getSamples(for: sensor, startDateTime: startDateTime, endDateTime: endDateTime)
                let sampleStrings = samples.map { $0.description }  // Customize based on your needs
                callback(nil, sampleStrings)
            } catch {
                logError("Error getting samples", error: error)
                callback(error.localizedDescription, [])
            }
        }
    }

    // MARK: Stats

    // TODO: Create SahhaStat struct and get stats directly from hkManager
    public static func getStats(
        sensor: SahhaSensor,
        startDateTime: Date,
        endDateTime: Date,
        callback: @escaping @Sendable (String?, [String]) -> Void
    ) {
        Task {
            do {
                guard startDateTime <= endDateTime else {
                    throw ValidationError.invalidDateRange
                }
                let hkManager = try await container.getHKManager()
                let stats = try await hkManager.getStats(for: sensor, startDateTime: startDateTime, endDateTime: endDateTime)
                let statStrings = stats.map { $0.description }  // Customize based on your needs
                callback(nil, statStrings)
            } catch {
                logError("Error getting stats", error: error)
                callback(error.localizedDescription, [])
            }
        }
    }

    // MARK: Scores

    public static func getScores(
        types: Set<SahhaScoreType>,
        startDateTime: Date,
        endDateTime: Date,
        callback: @escaping @Sendable (String?, String?) -> Void
    ) {
        Task {
            do {
                guard startDateTime <= endDateTime else {
                    throw ValidationError.invalidDateRange
                }
                guard !types.isEmpty else {
                    throw ValidationError.emptyCollection(collection: "types")
                }
                let scoreService = try await container.getScoreService()
                let scores = try await scoreService.getScores(types: types, startDateTime: startDateTime, endDateTime: endDateTime)
                let scoreJson = try scores.toDataWrappedJSON()
                callback(nil, scoreJson)
            } catch {
                logError("Error getting scores", error: error)
                callback(error.localizedDescription, nil)
            }
        }
    }

    // MARK: Biomarkers

    public static func getBiomarkers(
        categories: Set<SahhaBiomarkerCategory>,
        types: Set<SahhaBiomarkerType>,
        startDateTime: Date,
        endDateTime: Date,
        callback: @escaping @Sendable (String?, String?) -> Void
    ) {
        Task {
            do {
                guard startDateTime <= endDateTime else {
                    throw ValidationError.invalidDateRange
                }
                guard !categories.isEmpty else {
                    throw ValidationError.emptyCollection(collection: "categories")
                }
                guard !types.isEmpty else {
                    throw ValidationError.emptyCollection(collection: "types")
                }
                
                let biomarkerService = try await container.getBiomarkerService()
                let biomarkers = try await biomarkerService.getBiomarkers(
                    categories: categories,
                    types: types,
                    startDateTime: startDateTime,
                    endDateTime: endDateTime
                )
                let biomarkerJson = try biomarkers.toDataWrappedJSON()
                callback(nil, biomarkerJson)
            } catch {
                logError("Error getting scores", error: error)
                callback(error.localizedDescription, nil)
            }
        }
    }

    // MARK: Settings

    public static func openAppSettings() {
        Task { @MainActor in
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString),
                UIApplication.shared.canOpenURL(settingsURL)
            else {
                logError("Failed to open app settings: Invalid or unsupported settings URL.")
                return
            }

            await UIApplication.shared.open(settingsURL)
        }
    }

    // MARK: Errors

    private static func logError(_ message: String, error: Error? = nil) {
        Task {
            let errorInfo = error.map { "\($0) (\(type(of: $0)))" } ?? "No error details"
            let fullMessage = "\(message): \(errorInfo)"

            do {
                let logger = try await container.getLogger()
                logger.error(fullMessage)
            } catch {
                #if DEBUG
                    print("Failed to log error: \(message), error: \(errorInfo)")
                #endif
            }
        }
    }

}
