import Foundation
import UIKit
import CryptoKit

protocol DeviceInfoManagerProtocol: Actor {
    func getDeviceInfo() async -> DeviceInfoRequest
    func sync() async throws
    func clear() async throws
}

enum DeviceInfoError: Error, LocalizedError {
    case missingDeviceInfo
    
    var errorDescription: String? {
        switch self {
        case .missingDeviceInfo:
            return "Device info not available."
        }
    }
}

actor DeviceInfoManager: DeviceInfoManagerProtocol {
    private let userDefaults: UserDefaults
    private let settings: SahhaSettings
    private let deviceInfoService: DeviceInfoServiceProtocol
    
    private var cachedDeviceInfo: DeviceInfoRequest?
    private var cachedHash: String?
    
    private let deviceIdKey = "SahhaDeviceId"
    private let hashKey = "SahhaDeviceInfoHash"
    
    init(userDefaults: UserDefaults, settings: SahhaSettings, deviceInfoService: DeviceInfoServiceProtocol) {
        self.userDefaults = userDefaults
        self.settings = settings
        self.deviceInfoService = deviceInfoService
    }
    
    func getDeviceInfo() async -> DeviceInfoRequest {
        if let cached = cachedDeviceInfo {
            return cached
        }
        
        let device = await UIDevice.current
        let bundle = Bundle.main
        let deviceId = await getPersistentDeviceId()
        let deviceModel = getDeviceModel()
        
        let deviceInfo = await DeviceInfoRequest(
            sdkId: settings.framework.rawValue,
            sdkVersion: "1.0.0", // Replace with actual SDK version
            appId: bundle.bundleIdentifier ?? "unknown",
            appVersion: bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            deviceId: deviceId,
            deviceType: device.model,
            deviceModel: deviceModel,
            system: device.systemName,
            systemVersion: device.systemVersion,
            timeZone: Date().utcOffset
        )
        cachedDeviceInfo = deviceInfo
        do {
            cachedHash = try deviceInfo.sha256Hash()
        } catch {
            print("Failed to hash device info: \(error)")
            cachedHash = nil
        }
        return deviceInfo
    }
    
    func sync() async throws {
        let deviceInfo = await getDeviceInfo()
        
        guard let currentHash = cachedHash else {
            throw DeviceInfoError.missingDeviceInfo
        }
        
        let storedHash = userDefaults.string(forKey: hashKey)
        if storedHash != currentHash {
            try await deviceInfoService.updateDeviceInformation(deviceInfo)
            userDefaults.set(currentHash, forKey: hashKey)
        }
    }
    
    func clear() async {
        userDefaults.removeObject(forKey: hashKey)
        cachedDeviceInfo = nil
        cachedHash = nil
    }
    
    private func getPersistentDeviceId() async -> String {
        if let storedDeviceId = userDefaults.string(forKey: deviceIdKey) {
            return storedDeviceId
        }
        let newDeviceId = await UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        userDefaults.set(newDeviceId, forKey: deviceIdKey)
        return newDeviceId
    }
    
    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingCString: $0)
            }
        }
        return machine ?? "unknown"
    }
}
