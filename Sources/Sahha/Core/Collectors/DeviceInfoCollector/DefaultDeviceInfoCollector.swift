import UIKit

final actor DefaultDeviceInfoCollector: DeviceInfoCollector {
    private let framework: SahhaFramework
    private let deviceIdStore: DeviceIdStore
    
    init(
        framework: SahhaFramework,
        deviceIdStore: DeviceIdStore
    ) {
        self.framework = framework
        self.deviceIdStore = deviceIdStore
    }
    
    func collect() async -> DeviceInformation {
        await DeviceInformation(
            sdkId: framework.rawValue,
            sdkVersion: SDKConfig.version,
            appId: Bundle.main.bundleIdentifier ?? "unknown",
            appVersion: (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown",
            deviceId: deviceIdStore.getId(),
            deviceType: UIDevice.current.model,
            deviceModel: UIDevice.modelIdentifier,
            system: UIDevice.current.systemName,
            systemVersion: UIDevice.current.systemVersion,
            timeZone: Date().utcOffset
        )
    }
}

private extension UIDevice {
    static var modelIdentifier: String {
        var sysinfo = utsname(); uname(&sysinfo)
        return withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }
}
