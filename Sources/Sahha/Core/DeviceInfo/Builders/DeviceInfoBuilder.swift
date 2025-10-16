import UIKit

final class DeviceInfoBuilder: DeviceInfoBuilderProtocol {
    private let sdkId: String
    private let deviceIdProvider: DeviceIdProviderProtocol
    
    init(sdkId: String, deviceIdProvider: DeviceIdProviderProtocol) {
        self.sdkId = sdkId
        self.deviceIdProvider = deviceIdProvider
    }
    
    func build() async -> DeviceInfo {
        let appId = Bundle.main.bundleIdentifier ?? "unknown"
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let deviceId = await deviceIdProvider.deviceId()
        let timeZone = Date().utcOffset
        
        var sysinfo = utsname(); uname(&sysinfo)
        let deviceModel = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        
        let (deviceType, system, systemVersion) = await MainActor.run {
            let deviceType = UIDevice.current.model
            let system = UIDevice.current.systemName
            let systemVersion = UIDevice.current.systemVersion
            return (deviceType, system, systemVersion)
        }
        
        return DeviceInfo(
            sdkId: sdkId,
            sdkVersion: SDK.version,
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
}
