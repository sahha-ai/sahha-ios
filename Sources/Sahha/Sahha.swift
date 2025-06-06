import UIKit

public final class Sahha {
    @MainActor private static var profileTokenSnapshot: String?
    
    // MARK: Configuration
    
    public static func configure(_ settings: SahhaSettings, callback: (@Sendable () -> Void)? = nil) {
        Task {
            await ConfigurationStore.shared.set(settings)
            await restoreSessionIfNeeded()
            callback?()
        }
    }
    
    private static func restoreSessionIfNeeded() async {
        if let token = await TokenStore.shared.getProfileToken() {
            Task { @MainActor in
                setProfileTokenSnapshot(token)
                LifecycleObserver.shared.start()
            }
            
            await HKManager.shared.startSensors()
            await RefreshTokenManager.shared.scheduleRefresh()
        }
    }
    
    // MARK: Authentication
    
    static func setProfileTokenSnapshot(_ token: String?) {
        Task { @MainActor in
            profileTokenSnapshot = token
        }
    }
    
    @MainActor
    public static var isAuthenticated: Bool {
        return profileTokenSnapshot != nil
    }
    
    @MainActor
    public static var profileToken: String? {
        return profileTokenSnapshot
    }
    
    public static func authenticate(appId: String, appSecret: String, externalId: String, callback: @escaping @Sendable (String?, Bool) -> Void) {
        Task {
            let result = await ApiController.registerProfile(appId: appId, appSecret: appSecret, externalId: externalId)
            switch result {
            case .success(let tokens):
                authenticate(tokens, callback: callback)
            case .failure(let error):
                callback(error.localizedDescription, false)
            }
        }
    }
    
    public static func authenticate(profileToken: String, refreshToken: String, callback: @escaping @Sendable (String?, Bool) -> Void) {
        Task {
            let tokens = TokenResponse(profileToken: profileToken, refreshToken: refreshToken)
            authenticate(tokens, callback: callback)
        }
    }
    
    private static func authenticate(_ tokens: TokenResponse, callback: @escaping @Sendable (String?, Bool) -> Void) {
        Task {
            do {
                try await TokenStore.shared.setTokens(tokens)
                await HKManager.shared.startSensors()
                await LifecycleObserver.shared.start()
                callback(nil, true)
            } catch {
                callback(error.localizedDescription, false)
            }
        }
    }
    
    public static func deauthenticate(callback: @escaping @Sendable (String?, Bool) -> Void) {
        Task {
            do {
                // Delete PII (demographic) first
                try await DemographicStore.shared.clear()
                try await TokenStore.shared.deleteTokens()
                
                await LifecycleObserver.shared.stop()
                await SensorStore.shared.clearSensors()
                await HKAnchorStore.shared.clearAllAnchors()
                
                callback(nil, true)
            } catch {
                callback(error.localizedDescription, false)
            }
        }
    }
    
    // MARK: Sensors
    
    public static func enableSensors(_ sensors: Set<SahhaSensor>, callback: @escaping @Sendable (String?, SahhaSensorStatus) -> Void) {
        Task {
            let (error, status) = await SensorManager.shared.enableSensors(sensors)
            callback(error, status)
        }
    }
    
    public static func getSensorStatus(_ sensors: Set<SahhaSensor>, callback: @escaping @Sendable (String?, SahhaSensorStatus) -> Void) {
        Task {
            let (error, status) = await SensorManager.shared.getSensorStatus(sensors)
            callback(error, status)
        }
    }
    
    // MARK: Demographic
    
    public static func getDemographic(callback: @escaping @Sendable (String?, SahhaDemographic?) -> Void) {
        Task {
            if let cached = await DemographicStore.shared.get() {
                callback(nil, cached)
                return
            }
            
            let result = await ApiController.getDemographic()
            switch result {
            case .success(let response):
                let demographic = SahhaDemographic(from: response)
                do {
                    try await DemographicStore.shared.set(demographic)
                    callback(nil, demographic)
                } catch {
                    callback(error.localizedDescription, nil)
                }
            case .failure(let error):
                callback(error.localizedDescription, nil)
            }
        }
    }
    
    public static func postDemographic(_ demographic: SahhaDemographic, callback: @escaping @Sendable (String?, Bool) -> Void) {
        Task {
            let cached = await DemographicStore.shared.get()
            
            if cached == demographic {
                callback(nil, true)
                return
            }
            
            let request = demographic.toRequest()
            let result = await ApiController.patchDemographic(request)
            switch result {
            case .success:
                do {
                    try await DemographicStore.shared.set(demographic)
                    callback(nil, true)
                } catch {
                    callback(error.localizedDescription, false)
                }
            case .failure(let error):
                callback(error.localizedDescription, false)
            }
        }
    }
    
    // MARK: Samples
    
    public static func getSamples() {
        // TODO: Implement me!
    }
    
    // MARK: Stats
    
    public static func getStats() {
        // TODO: Implement me!
    }
    
    // MARK: Scores
    
    public static func getScores(
        types: Set<String>,
        startDateTime: Date,
        endDateTime: Date,
        callback: @escaping @Sendable (String?, String?) -> Void
    ) {
        Task {
            let result = await ApiController.getScores(types: types, startDateTime: startDateTime, endDateTime: endDateTime)
            switch result {
            case .success(let scores):
                let (error, json) = scores.wrappedAsDataEnvelope(named: "scores")
                callback(error, json)
            case .failure(let error):
                callback(error.localizedDescription, nil)
            }
        }
    }
    
    // MARK: Biomarkers
    
    public static func getBiomarkers(
        categories: Set<String>,
        types: Set<String>,
        startDateTime: Date,
        endDateTime: Date,
        callback: @escaping @Sendable (String?, String?) -> Void
    ) {
        Task {
            let result = await ApiController.getBiomarkers(categroies: categories, types: types, startDateTime: startDateTime, endDateTime: endDateTime)
            switch result {
            case .success(let biomarkers):
                let (error, json) = biomarkers.wrappedAsDataEnvelope(named: "biomarkers")
                callback(error, json)
            case .failure(let error):
                callback(error.localizedDescription, nil)
            }
        }
    }
    
    // MARK: Settings
    
    @MainActor
    public static func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(settingsURL) else {
            print("Sahha SDK: Invalid or unsupported settings URL.")
            return
        }
        
        UIApplication.shared.open(settingsURL)
    }
}

// MARK: Helpers

private extension Encodable {
    func wrappedAsDataEnvelope(named typeName: String) -> (error: String?, data: String?) {
        let wrapper = ["data": self]
        
        do {
            let json = try wrapper.toJsonString()
            return (nil, json)
        } catch {
            return (error.localizedDescription, nil)
        }
    }
}
