import UIKit

/*:
 TODO:
 
 - Inject logging
 - HK Anchors stored against uuid v5 of appId, appSecret and externalId
 - isAuthenticated validation for sensors and public funcs etc.
 - Validation on service funcs for early return
 - Resume sensors and HK stuff on app init
 - AppEvents feature (inject SensorsManager, DataLogProcessor etc.)
 - Get stats / get samples
 - Stub DataLogAggregator and inject into DataLogProcessor
 
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
            } catch {
                print("Failed to configure Sahha: \(error.localizedDescription)")
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
                callback(nil, true)
            } catch {
                print("Failed to authenticate: \(error.localizedDescription)")
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
                callback(nil, true)
            } catch {
                print("Failed to authenticate: \(error.localizedDescription)")
                callback(error.localizedDescription, false)
            }
        }
    }

    // TODO: Add disposables where needed and reset container on deauthenticate
    public static func deauthenticate(callback: @escaping @Sendable (String?, Bool) -> Void) {
        Task {
            do {
                try await container.deauthenticate()
                callback(nil, true)
            } catch {
                print("Failed to deauthenticate: \(error.localizedDescription)")
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
                print("Failed to get demographic: \(error.localizedDescription)")
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
                print("Failed to get demographic: \(error.localizedDescription)")
                callback(error.localizedDescription, false)
            }
        }
    }

    // MARK: Sensors

    public static func enableSensors(_ sensors: Set<SahhaSensor>, callback: @escaping @Sendable (String?, SahhaSensorStatus) -> Void) {
        Task {
            do {
                let sensorsManager = try await container.getSensorsManager()
                await sensorsManager.enableSensors(sensors)
                callback(nil, .pending)
            } catch {
                print("Error enabling sensors: \(error.localizedDescription)")
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
                print("Error getting scores: \(error.localizedDescription)")
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
                print("Error getting scores: \(error.localizedDescription)")
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
                print("Invalid or unsupported settings URL.")
                return
            }

            await UIApplication.shared.open(settingsURL)
        }
    }
}
