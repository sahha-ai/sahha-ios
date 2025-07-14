import Foundation
import UIKit

protocol DeviceInformationProvider {
    func getDeviceInformation() async -> DeviceInformation
}

final actor DeviceInfoProviderImpl: DeviceInformationProvider {
    private let framework: SahhaFramework
    private let deviceIdStore: DeviceIdStore

    init(framework: SahhaFramework, deviceIdStore: DeviceIdStore) {
        self.framework = framework
        self.deviceIdStore = deviceIdStore
    }

    func getDeviceInformation() async -> DeviceInformation {
        DeviceInformation(
            sdkId: framework.rawValue,
            sdkVersion: Constants.sdkVersion,
            appId: Bundle.main.bundleIdentifier ?? "unknown",
            appVersion: (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown",
            deviceId: await deviceIdStore.getDeviceId(),
            deviceType: await UIDevice.current.model,
            deviceModel: getDeviceModel(),
            system: await UIDevice.current.systemName,
            systemVersion: await UIDevice.current.systemVersion,
            timeZone: Date().utcOffset
        )
    }

    private func getDeviceModel() -> String {
        var systemInfo = utsname()

        guard uname(&systemInfo) == 0 else { return "unknown" }

        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 256) {
                String(cString: $0)
            }
        }
    }
}
