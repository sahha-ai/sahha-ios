import UIKit

struct AuthSnapshot {
    let profileToken: String?
    let expiry: Date?
}

public final class Sahha {
    private static let sahhaActor: SahhaActor = .shared

    @MainActor private static var authSnapshot: AuthSnapshot?

    // MARK: Configuration

    public static func configure(_ settings: SahhaSettings, callback: (@Sendable () -> Void)? = nil) {
        Task {
            do {
                try await sahhaActor.configure(with: settings)
            } catch {
                print("Failed to configure Sahha: \(error.localizedDescription)")
            }
            callback?()
        }
    }

    // MARK: Authentication

    @MainActor
    public static var isAuthenticated: Bool {
        guard let snapshot = authSnapshot else {
            return false
        }
        let hasToken = snapshot.profileToken != nil && snapshot.profileToken?.isEmpty == false
        let tokenIsValid = (snapshot.expiry ?? Date.distantPast) > Date()
        return hasToken && tokenIsValid
    }

    @MainActor
    public static var profileToken: String? {
        authSnapshot?.profileToken
    }

    static func setAuthSnapshot(_ snapshot: AuthSnapshot) async {
        await MainActor.run {
            authSnapshot = snapshot
        }
    }

    public static func authenticate(
        appId: String,
        appSecret: String,
        externalId: String,
        callback: @escaping @Sendable (String?, Bool) -> Void
    ) {
        Task {
            do {
                try await validate([
                    { checkNotEmpty(appId, field: "appId") },
                    { checkNotEmpty(appSecret, field: "appSecret") },
                    { checkNotEmpty(externalId, field: "externalId") },
                ])
                let authService = try await sahhaActor.getAuthService()
                let response = try await authService.registerProfile(appId: appId, appSecret: appSecret, externalId: externalId)
                try await authenticate(response)
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
                try await validate([
                    { checkNotEmpty(profileToken, field: "profileToken") },
                    { checkNotEmpty(refreshToken, field: "refreshToken") },
                ])
                let response = TokenResponse(profileToken: profileToken, refreshToken: refreshToken)
                try await authenticate(response)
                callback(nil, true)
            } catch {
                callback(error.localizedDescription, false)
            }
        }
    }

    private static func authenticate(_ response: TokenResponse) async throws {
        let tokenManager = try await sahhaActor.getTokenManager()
        try await tokenManager.saveTokenResponse(response)
        let deviceInfoStore = try await sahhaActor.getDeviceInfoStore()
        await deviceInfoStore.forceSync()
    }

    public static func deauthenticate(callback: @escaping @Sendable (String?, Bool) -> Void) {
        Task {
            do {
                try await sahhaActor.reset()
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
                try await validate([
                    { await checkAuthentication() }
                ])
                let demographicStore = try await sahhaActor.getDemographicStore()
                let demographic = try await demographicStore.getDemographic()
                callback(nil, demographic)
            } catch {
                callback(error.localizedDescription, nil)
            }
        }
    }

    public static func postDemographic(_ demographic: SahhaDemographic, callback: @escaping @Sendable (String?, Bool) -> Void) {
        Task {
            do {
                try await validate([
                    { await checkAuthentication() }
                ])
                let demographicStore = try await sahhaActor.getDemographicStore()
                try await demographicStore.updateDemographic(demographic)
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
                try await validate([
                    { await checkAuthentication() },
                    { checkNotEmptyCollection(sensors, name: "sensors") },
                ])
                let hkManager = try await sahhaActor.getHkManager()
                try await hkManager.enableSensors(sensors)
                let status = try await hkManager.getSensorStatus(sensors)
                callback(nil, status)
            } catch {
                callback(error.localizedDescription, .pending)
            }
        }
    }

    public static func getSensorStatus(_ sensors: Set<SahhaSensor>, callback: @escaping @Sendable (String?, SahhaSensorStatus) -> Void) {
        Task {
            do {
                try await validate([
                    { await checkAuthentication() },
                    { checkNotEmptyCollection(sensors, name: "sensors") },
                ])
                let hkManager = try await sahhaActor.getHkManager()
                let status = try await hkManager.getSensorStatus(sensors)
                callback(nil, status)
            } catch {
                callback(error.localizedDescription, .pending)
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
                try await validate([
                    { checkDateRange(start: startDateTime, end: endDateTime) },
                ])
                let hkManager = try await sahhaActor.getHkManager()
                let samples = try await hkManager.getSamples(for: sensor, startDateTime: startDateTime, endDateTime: endDateTime)
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
                try await validate([
                    { checkDateRange(start: startDateTime, end: endDateTime) },
                ])
                let hkManager = try await sahhaActor.getHkManager()
                let stats = try await hkManager.getStats(for: sensor, startDateTime: startDateTime, endDateTime: endDateTime)
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
                try await validate([
                    { await checkAuthentication() },
                    { checkNotEmptyCollection(types, name: "types") },
                    { checkDateRange(start: startDateTime, end: endDateTime) },
                ])
                let scoreService = try await sahhaActor.getScoreService()
                let scores = try await scoreService.getScores(types: types, startDateTime: startDateTime, endDateTime: endDateTime)
                let scoreJson = try scores.toDataWrappedJSON()
                callback(nil, scoreJson)
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
                try await validate([
                    { await checkAuthentication() },
                    { checkNotEmptyCollection(categories, name: "categories") },
                    { checkNotEmptyCollection(types, name: "types") },
                    { checkDateRange(start: startDateTime, end: endDateTime) },
                ])
                let biomarkerService = try await sahhaActor.getBiomarkerService()
                let biomarkers = try await biomarkerService.getBiomarkers(
                    categories: categories,
                    types: types,
                    startDateTime: startDateTime,
                    endDateTime: endDateTime
                )
                let biomarkerJson = try biomarkers.toDataWrappedJSON()
                callback(nil, biomarkerJson)
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

    // MARK: Validation Helpers

    typealias AsyncValidationCheck = () async -> ValidationError?

    static func validate(_ checks: [AsyncValidationCheck]) async throws {
        var errors: [ValidationError] = []
        for check in checks {
            if let error = await check() {
                errors.append(error)
            }
        }
        if !errors.isEmpty {
            throw ValidationError.validationFailed(errors)
        }
    }

    static func checkAuthentication() async -> ValidationError? {
        await MainActor.run {
            !Sahha.isAuthenticated ? .authenticationRequired : nil
        }
    }

    static func checkNotEmpty(_ str: String, field: String) -> ValidationError? {
        str.isEmpty ? .emptyString(field: field) : nil
    }

    static func checkNotEmptyCollection<T>(_ collection: T, name: String) -> ValidationError? where T: Collection {
        collection.isEmpty ? .emptyCollection(collection: name) : nil
    }

    static func checkDateRange(start: Date, end: Date) -> ValidationError? {
        start > end ? .invalidDateRange : nil
    }
}
