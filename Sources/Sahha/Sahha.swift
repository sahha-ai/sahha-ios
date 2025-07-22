import Foundation
import UIKit

public final class Sahha {
    private static let actor: SahhaActor = .shared
    
    // MARK: Configuration
    public static func configure(_ settings: SahhaSettings, callback: (@Sendable () -> Void)? = nil) {
        Task {
            do {
                try await actor.configure(settings)
                callback?()
            } catch {
                print("Error while configuring Sahha: \(error)")
            }
        }
    }
    
    // MARK: Authentication
    
    // Auth snapshot to keep isAuthenticated and profileToken vars sync.
    static let authSnapshot = AuthSnapshot()
    
    public static var isAuthenticated: Bool {
        return authSnapshot.isAuthenticated
    }
    
    public static var profileToken: String? {
        return authSnapshot.profileToken
    }
    
    public static func authenticate(
        appId: String,
        appSecret: String,
        externalId: String,
        callback: @escaping @Sendable (String?, Bool) -> Void
    ) {
        Task {
            do {
                let authManager = try await actor.getAuthManager()
                try await authManager.authorize(appId: appId, appSecret: appSecret, externalId: externalId)
                try await actor.onAuthenticated()
                callback(nil, true)
            } catch {
                callback(error.localizedDescription, false)
            }
        }
    }
    
    public static func authenticate(
        profileToken: String,
        refreshToken: String,
        callback: @escaping @Sendable (String?, Bool) -> Void
    ) {
        Task {
            do {
                let authManager = try await actor.getAuthManager()
                try await authManager.authorize(profileToken: profileToken, refreshToken: refreshToken)
                try await actor.onAuthenticated()
                callback(nil, true)
            } catch {
                callback(error.localizedDescription, false)
            }
        }
    }
    
    public static func deauthenticate(callback: @escaping @Sendable (String?, Bool) -> Void) {
        Task {
            do {
                try await actor.resetContainer()
                callback(nil, true)
            } catch {
                callback(error.localizedDescription, false)
            }
        }
    }
    
    // MARK: Demographic
    public static func getDemographic(callback: @escaping @Sendable (String?, SahhaDemographic?) -> Void) {
        Task {
            do {
                let demographicManager = try await actor.getDemographicManager()
                let demographic = try await demographicManager.getDemographic()
                callback(nil, demographic)
            } catch {
                callback(error.localizedDescription, nil)
            }
        }
    }
    
    public static func postDemographic(_ demographic: SahhaDemographic, callback: @escaping @Sendable (String?, Bool) -> Void) {
        Task {
            do {
                let demographicManager = try await actor.getDemographicManager()
                try await demographicManager.updateDemographic(demographic)
                callback(nil, true)
            } catch {
                callback(error.localizedDescription, false)
            }
        }
    }
    
    // MARK: Sensors
    public static func enableSensors(_ sensors: Set<SahhaSensor>, callback: @escaping @Sendable (String?, SahhaSensorStatus) -> Void) {
        Task {
            do {
                let sensorManager = try await actor.getSensorManager()
                try await sensorManager.enableSensors(sensors)
                let status = try await sensorManager.getSensorStatus(sensors)
                callback(nil, status)
            } catch {
                callback(error.localizedDescription, .unavailable)
            }
        }
    }
    
    public static func getSensorStatus(_ sensors: Set<SahhaSensor>, callback: @escaping @Sendable (String?, SahhaSensorStatus) -> Void) {
        Task {
            do {
                let sensorManager = try await actor.getSensorManager()
                let status = try await sensorManager.getSensorStatus(sensors)
                callback(nil, status)
            } catch {
                callback(error.localizedDescription, .unavailable)
            }
        }
    }
    
    // MARK: Samples
    public static func getSamples(
        sensor: SahhaSensor,
        startDateTime: Date,
        endDateTime: Date,
        callback: @escaping @Sendable (String?, [SahhaSample]) -> Void
    ) {
        Task {
            do {
                let sensorManager = try await actor.getSensorManager()
                let samples = try await sensorManager.getSamples(for: sensor, startDateTime: startDateTime, endDateTime: endDateTime)
                callback(nil, samples)
            } catch {
                callback(error.localizedDescription, [])
            }
        }
    }
    
    // MARK: Stats
    public static func getStats(
        sensor: SahhaSensor,
        startDateTime: Date,
        endDateTime: Date,
        callback: @escaping @Sendable (String?, [SahhaStat]) -> Void
    ) {
        Task {
            do {
                let sensorManager = try await actor.getSensorManager()
                let stats = try await sensorManager.getStats(for: sensor, startDateTime: startDateTime, endDateTime: endDateTime)
                callback(nil, stats)
            } catch {
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
                let scoreService = try await actor.getScoreService()
                let scores = try await scoreService.getScores(
                    types: types,
                    startDateTime: startDateTime,
                    endDateTime: endDateTime
                )
                callback(nil, "") // TODO
            } catch {
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
                let biomarkerService = try await actor.getBiomarkerService()
                let biomarkers = try await biomarkerService.getBiomarkers(
                    categories: categories,
                    types: types,
                    startDateTime: startDateTime,
                    endDateTime: endDateTime
                )
                callback(nil, "") // TODO
            } catch {
                callback(error.localizedDescription, nil)
            }
        }
    }
    
    // MARK: Settings
    public static func openAppSettings() {
        Task { @MainActor in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString),
                UIApplication.shared.canOpenURL(settingsURL)
            {
                await UIApplication.shared.open(settingsURL)
            } else {
                print("Failed to open app settings: Invalid or unsupported settings URL.")
            }
        }
    }
}
