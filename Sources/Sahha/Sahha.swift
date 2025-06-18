import Foundation
import UIKit

public final class Sahha {
    private static let container = SahhaServiceContainer.shared
    
    // MARK: Configuration
    
    public static func configure(settings: SahhaSettings, callback: (@Sendable () -> Void)? = nil) {
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
    
    public static func authenticate(appId: String, appSecret: String, externalId: String, callback: @escaping @Sendable (String?, Bool) -> Void) {
        Task {
            do {
                let authService = try await container.getAuthenticationService()
                let tokenManager = try await container.getTokenManager()
                let deviceInfoManager = try await container.getDeviceInfoManager()
                
                let response = try await authService.authenticate(appId: appId, appSecret: appSecret, externalId: externalId)
                try await tokenManager.save(response)
                try await deviceInfoManager.sync()
                
                callback(nil, true)
            } catch {
                print("Authentication error: \(error)")
                callback(error.localizedDescription, false)
            }
        }
    }
    
    public static func authenticate(profileToken: String, refreshToken: String, callback: @escaping @Sendable (String?, Bool) -> Void) {
        Task {
            do {
                let tokenManager = try await container.getTokenManager()
                let deviceInfoManager = try await container.getDeviceInfoManager()
                
                let response = AuthenticationResponse(profileToken: profileToken, refreshToken: refreshToken)
                try await tokenManager.save(response)
                try await deviceInfoManager.sync()
                
                callback(nil, true)
            } catch {
                print("Authentication error: \(error.localizedDescription)")
                callback(error.localizedDescription, false)
            }
        }
    }
    
    public static func deauthenticate(callback: @escaping @Sendable (String?, Bool) -> Void) {
        fatalError("Not yet implemented")
    }
    
    // MARK: Sensors
    
    public static func enableSensors(_ sensors: Set<SahhaSensor>, callback: @escaping @Sendable (String?, SahhaSensorStatus) -> Void) {
        Task {
            do {
                let sensorManager = try await container.getSensorManager()
                try await sensorManager.enableSensors(sensors)
            } catch {
                print("Error enabling sensors: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: Scores
    
    public static func getScores(types: Set<String>, startDateTime: Date, endDateTime: Date, callback: @escaping @Sendable (String?, String?) -> Void) {
        Task {
            do {
                let scoreService = try await container.getScoreService()
                let _ = try await scoreService.getScores(types: types, startDateTime: startDateTime, endDateTime: endDateTime)
                callback(nil, "") // TODO: JSON stringify scores as {data: [ {...} ]}
            } catch {
                print("Get scores error: \(error)")
                callback(error.localizedDescription, nil)
            }
        }
    }
    
    // MARK: Biomarkers
    
    public static func getBiomarkers(categories: Set<String>, types: Set<String>, startDateTime: Date, endDateTime: Date, callback: @escaping @Sendable (String?, String?) -> Void) {
        Task {
            do {
                let biomarkerService = try await container.getBiomarkerService()
                let _ = try await biomarkerService.getBiomarkers(categories: categories, types: types, startDateTime: startDateTime, endDateTime: endDateTime)
                callback(nil, "") // TODO: JSON stringify biomarkers as [data: [ {...} ]]
            } catch {
                print("Get biomarkers error: \(error)")
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
