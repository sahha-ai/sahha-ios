import Foundation
import UIKit
import CryptoKit

protocol DeviceInfoStoreProtocol: Actor {
    var deviceInfo: DeviceInfoRequest {get}
}

actor DeviceInfoStore: DeviceInfoStoreProtocol {
    private let framework: SahhaFramework
    private let userDefaults: UserDefaults
    private let deviceIdKey = "SahhaDeviceId"
    
    var deviceInfo: DeviceInfoRequest
    
    init(userDefaults: UserDefaults = .standard, framework: SahhaFramework) async {
        self.userDefaults = userDefaults
        self.framework = framework
        
        let device = await UIDevice.current
        let bundle = Bundle.main
        
        var deviceId: String
        
        if let storedDeviceId = userDefaults.string(forKey: deviceIdKey) {
            deviceId = storedDeviceId
        }
        let newDeviceId = await UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        userDefaults.set(newDeviceId, forKey: deviceIdKey)
        deviceId = newDeviceId
        
        var systemInfo = utsname()
        uname(&systemInfo)
        let deviceModel = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingCString: $0)
            }
        } ?? "unknown"
        
        self.deviceInfo = await DeviceInfoRequest(
            sdkId: framework.rawValue,
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
    }
}
