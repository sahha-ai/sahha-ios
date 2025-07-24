import Foundation
import UIKit

public final class Sahha {
    private static let actor: SahhaActor = .shared
    static let authSnapshot = AuthSnapshot()

    // MARK: Configuration

    public static func configure(
        _ settings: SahhaSettings,
        callback: (@Sendable () -> Void)? = nil
    ) {
        Task {
            do {
                try await actor.configure(with: settings)
                try await actor.startAuthenticatedServicesIfTokenPresent()
            } catch {
                print("An error occurred while configuring Sahha: \(error)")
            }
            if let callback = callback {
                await MainActor.run { callback() }
            }
        }
    }

    // MARK: Authentication

    public static var profileToken: String? { authSnapshot.profileToken }

    public static var isAuthenticated: Bool { authSnapshot.isAuthenticated }

    public static func authenticate(
        appId: String,
        appSecret: String,
        externalId: String,
        callback: @escaping @Sendable (String?, Bool) -> Void
    ) {
        Task {
            do {
                try await SahhaValidator.validateAuthenticate(appId: appId, appSecret: appSecret, externalId: externalId)
                let authService = try await actor.getAuthService()
                try await authService.authenticate(appId: appId, appSecret: appSecret, externalId: externalId)
                try await actor.startAuthenticatedServices()
                await MainActor.run { callback(nil, true) }
            } catch {
                print(error)
                await MainActor.run { callback(error.localizedDescription, false) }
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
                try await SahhaValidator.validateAuthenticate(profileToken: profileToken, refreshToken: refreshToken)
                let authService = try await actor.getAuthService()
                try await authService.authenticate(profileToken: profileToken, refreshToken: refreshToken)
                try await actor.startAuthenticatedServices()
                await MainActor.run { callback(nil, true) }
            } catch {
                print(error)
                await MainActor.run { callback(error.localizedDescription, false) }
            }
        }
    }

    public static func deauthenticate(callback: @escaping @Sendable (String?, Bool) -> Void) {
        Task {
            do {
                try await actor.resetContainer()
                await MainActor.run { callback(nil, true) }
            } catch {
                print(error)
                await MainActor.run { callback(error.localizedDescription, false) }
            }
        }
    }

    // MARK: Demographic

    public static func getDemographic(callback: @escaping @Sendable (String?, SahhaDemographic?) -> Void) {
        Task {
            do {
                try await SahhaValidator.validateGetDemographic()
                let demographicService = try await actor.getDemographicService()
                let demographic = try await demographicService.getDemographic()
                await MainActor.run { callback(nil, demographic) }
            } catch {
                print(error)
                await MainActor.run { callback(error.localizedDescription, nil) }
            }
        }
    }

    public static func postDemographic(
        _ demographic: SahhaDemographic,
        callback: @escaping @Sendable (String?, Bool) -> Void
    ) {
        Task {
            do {
                try await SahhaValidator.validatePostDemographic()
                let demographicService = try await actor.getDemographicService()
                try await demographicService.updateDemographic(demographic)
                callback(nil, true)
            } catch {
                print(error)
                await MainActor.run { callback(error.localizedDescription, false) }
            }
        }
    }

    // MARK: Sensors

    public static func enableSensors(
        _ sensors: Set<SahhaSensor>,
        callback: @escaping @Sendable (String?, SahhaSensorStatus) -> Void
    ) {
        Task {
            do {
                try await SahhaValidator.validateEnableSensors(sensors: sensors)
                let sensorManager = try await actor.getSensorManager()
                try await sensorManager.enableSensors(sensors)
                let status = try await sensorManager.getSensorStatus(sensors)
                await MainActor.run { callback(nil, status) }
            } catch {
                print(error)
                let status: SahhaSensorStatus = {
                    if let hkError = error as? HealthKitError, case .healthKitUnavailable = hkError {
                        return .unavailable
                    }
                    return .pending
                }()
                await MainActor.run { callback(error.localizedDescription, status) }
            }
        }
    }

    public static func getSensorStatus(
        _ sensors: Set<SahhaSensor>,
        callback: @escaping @Sendable (String?, SahhaSensorStatus) -> Void
    ) {
        Task {
            do {
                try await SahhaValidator.validateGetSensorStatus(sensors: sensors)
                let sensorManager = try await actor.getSensorManager()
                let status = try await sensorManager.getSensorStatus(sensors)
                await MainActor.run { callback(nil, status) }
            } catch {
                print(error)
                let status: SahhaSensorStatus = {
                    if let hkError = error as? HealthKitError, case .healthKitUnavailable = hkError {
                        return .unavailable
                    }
                    return .pending
                }()
                await MainActor.run { callback(error.localizedDescription, status) }
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
                try await SahhaValidator.validateGetSamples(startDate: startDateTime, endDate: endDateTime)
                let healthKitService = try await actor.getHealthKitService()
                let samples = try await healthKitService.getSamples(for: sensor, startDateTime: startDateTime, endDateTime: endDateTime)
                await MainActor.run { callback(nil, samples) }
            } catch {
                print(error)
                await MainActor.run { callback(error.localizedDescription, []) }
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
                try await SahhaValidator.validateGetStats(startDate: startDateTime, endDate: endDateTime)
                let healthKitService = try await actor.getHealthKitService()
                let stats = try await healthKitService.getStats(for: sensor, startDateTime: startDateTime, endDateTime: endDateTime)
                await MainActor.run { callback(nil, stats) }
            } catch {
                print(error)
                await MainActor.run { callback(error.localizedDescription, []) }
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
                try await SahhaValidator.validateGetScores(types: types, startDate: startDateTime, endDate: endDateTime)
                let scoreService = try await actor.getScoreService()
                let scores = try await scoreService.fetchScores(types: types, startDateTime: startDateTime, endDateTime: endDateTime)
                let jsonString = try scores.asDataJsonString()
                await MainActor.run { callback(nil, jsonString) }
            } catch {
                print(error)
                await MainActor.run { callback(error.localizedDescription, nil) }
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
                try await SahhaValidator.validateGetBiomarkers(categories: categories, types: types, startDate: startDateTime, endDate: endDateTime)
                let biomarkerService = try await actor.getBiomarkerService()
                let biomarkers = try await biomarkerService.fetchBiomarkers(
                    categories: categories,
                    types: types,
                    startDateTime: startDateTime,
                    endDateTime: endDateTime
                )
                let jsonString = try biomarkers.asDataJsonString()
                await MainActor.run { callback(nil, jsonString) }
            } catch {
                print(error)
                await MainActor.run { callback(error.localizedDescription, nil) }
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

// TEMPORARY: Legacy JSON bridge for old API compatibility.
// This extension is a stop-gap. It wraps an array in a "data" JSON structure and returns it as a string.
// NOTE: Remove this extension and return properly typed arrays from the public API in a future SDK release.
extension Array where Element: Encodable {
    fileprivate func asDataJsonString() throws -> String {
        let wrapper = ["data": self]
        let jsonData = try JSONEncoder().encode(wrapper)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw NSError(
                domain: "Sahha.JSONEncoding",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode JSON data to UTF-8 string."]
            )
        }
        return jsonString
    }
}
