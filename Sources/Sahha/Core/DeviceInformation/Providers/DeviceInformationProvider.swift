import Foundation
import UIKit

final class DeviceInformationProvider {
    private let userDefaults: UserDefaults
    private let deviceIdKey = Constants.UserDefaultsKeys.deviceId

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func getDeviceInformation(settings: SahhaSettings) async -> DeviceInformation {
        let sdkId = settings.environment.rawValue
        let sdkVersion = Constants.sdkVersion
        let appId = Bundle.main.bundleIdentifier ?? "unknown"
        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
        let deviceId = await getDeviceId()
        let deviceType = await UIDevice.current.model
        let deviceModel = getDeviceModel()
        let system = await UIDevice.current.systemName
        let systemVersion = await UIDevice.current.systemVersion
        let timeZone = Date().utcOffset

        return DeviceInformation(
            sdkId: sdkId,
            sdkVersion: sdkVersion,
            appId: appId,
            appVersion: appVersion,
            deviceId: deviceId,
            deviceType: deviceType,
            deviceModel: deviceModel,
            system: system,
            systemVersion: systemVersion,
            timeZone: timeZone
        )
    }

    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        if uname(&systemInfo) == 0 {
            return withUnsafePointer(to: &systemInfo.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: 256) {
                    String(cString: $0)
                }
            }
        }
        return "unknown"
    }

    private func getDeviceId() async -> String {
        if let storedDeviceId = userDefaults.string(forKey: deviceIdKey) {
            return storedDeviceId
        }
        let newDeviceId = await UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        userDefaults.set(newDeviceId, forKey: deviceIdKey)
        return newDeviceId
    }
}
