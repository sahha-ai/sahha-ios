import Foundation
import UIKit
import CryptoKit

protocol DeviceInfoManagerProtocol: Actor {
    func getDeviceInfo() async -> DeviceInfoRequest
    func hasDeviceInfoChanged() async throws -> Bool
    func saveDeviceInfoHash() async throws
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
    
    private var cachedDeviceInfo: DeviceInfoRequest?
    
    private let deviceIdKey = "SahhaDeviceId"
    private let hashKey = "SahhaDeviceInfoHash"
    
    init(userDefaults: UserDefaults, settings: SahhaSettings) {
        self.userDefaults = userDefaults
        self.settings = settings
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
            deviceId: device.identifierForVendor?.uuidString ?? UUID().uuidString,
            deviceType: device.model,
            deviceModel: deviceModel,
            system: device.systemName,
            systemVersion: device.systemVersion,
            timeZone: Date().utcOffset
        )
        cachedDeviceInfo = deviceInfo
        return deviceInfo
    }
    
    func hasDeviceInfoChanged() async throws -> Bool {
        let currentDeviceInfo = await getDeviceInfo()
        let currentHash = try hashDeviceInfo(currentDeviceInfo)
        let storedHash = userDefaults.string(forKey: hashKey)
        return currentHash != storedHash
    }
    
    func saveDeviceInfoHash() async throws {
        guard let deviceInfo = cachedDeviceInfo else {
            throw DeviceInfoError.missingDeviceInfo
        }
        let hash = try hashDeviceInfo(deviceInfo)
        userDefaults.set(hash, forKey: hashKey)
    }
    
    func clear() async {
        userDefaults.removeObject(forKey: hashKey)
        cachedDeviceInfo = nil
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
        return machine ?? ""
    }
    
    private func hashDeviceInfo(_ deviceInfo: DeviceInfoRequest) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys // Ensure consistent hashing
        let data = try encoder.encode(deviceInfo)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}
