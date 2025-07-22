import UIKit

struct DeviceInfoCollector: DeviceInfoCollecting {
    let deviceIdStore: DeviceIdStoring
    let sdkId: String

    init(
        deviceIdStore: DeviceIdStoring,
        sdkId: String,
    ) {
        self.deviceIdStore = deviceIdStore
        self.sdkId = sdkId
    }

    func collect() async throws -> DeviceInformation {
        let bundle = Bundle.main
        let device = await UIDevice.current
        let deviceId = try await deviceIdStore.getDeviceId()
        
        var sysinfo = utsname()
        uname(&sysinfo)
        let deviceModel = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }

        return DeviceInformation(
            sdkId: sdkId,
            sdkVersion: SdkInfo.version,
            appId: bundle.bundleIdentifier ?? "unknown",
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            deviceId: deviceId,
            deviceType: await device.model,
            deviceModel: deviceModel,
            system: await device.systemName,
            systemVersion: await device.systemVersion,
            timeZone: Date().utcOffset
        )
    }
}
