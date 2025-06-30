import UIKit

/*:
 TODO:

 - Get sensor status
 - Get stats / get samples
 - Stub DataLogAggregator and inject into DataLogProcessor
 - DataLog additional properties
 - HKNormaliser for each data type.
 
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
                let sensorsManager = try await container.getSensorsManager()
                try await sensorsManager.enableSensors(sensors)
                callback(nil, .pending)
            } catch {
                logError("Error enabling sensors", error: error)
                callback(error.localizedDescription, .disabled)
            }
        }
    }

    // MARK: Samples

    // TODO: Create SahhaSample struct and get samples directly from hkManager
    public static func getSamples(sensor: SahhaSensor, startDateTime: Date, endDateTime: Date, callback: @escaping (String?, [String]) -> Void) {
        Task {
            fatalError("Not implemented")
        }
    }

    // MARK: Stats

    // TODO: Create SahhaStat struct and get stats directly from hkManager
    public static func getStats(sensor: SahhaSensor, startDateTime: Date, endDateTime: Date, callback: @escaping (String?, [String]) -> Void) {
        Task {
            fatalError("Not implemented")
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
            do {
                let logger = try await container.getLogger()
                let fullMessage = error != nil ? "\(message): \(error!.localizedDescription)" : message
                logger.error(fullMessage)
            } catch {
                #if DEBUG
                    print("Failed to log error: \(message)")
                #endif
            }
        }
    }

}
