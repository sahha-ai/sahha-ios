import UIKit

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

    static func updateToken(token: String?, expiry: Date?) {
        Task { @MainActor in
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
                callback(nil, "") // TODO: Return json string {data: [...]}
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
                let biomarkers = try await biomarkerService.getBiomarkers(categories: categories, types: types, startDateTime: startDateTime, endDateTime: endDateTime)
                callback(nil, "") // TODO: Return json string {data: [...]}
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
