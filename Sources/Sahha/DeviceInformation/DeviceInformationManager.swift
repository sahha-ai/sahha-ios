import Foundation
import UIKit
import CryptoKit

final actor DeviceInformationManager {
    static let shared = DeviceInformationManager()

    func collect() async -> DeviceInformationRequest {
        let framework = await ConfigurationStore.shared.getFramework() ?? SahhaFramework.ios_swift
        let bundle = Bundle.main
        
        let (deviceType, system, systemVersion): (String, String, String) = await MainActor.run {
            let device = UIDevice.current
            return (device.model, device.systemName, device.systemVersion)
        }

        let sdkId = framework.rawValue
        let sdkVersion = "1.0.0" // consider centralizing this in a Constants file
        let appId = bundle.bundleIdentifier ?? "unknown"
        let appVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let deviceId = await DeviceIdStore.shared.getDeviceId()
        let deviceModel = getDeviceModel()
        let timeZone = Date().utcOffset

        return DeviceInformationRequest(
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

    func sync() async {
        let info = await collect()

        guard let newHash = try? hash(info) else { return }

        let previousHash = await DeviceInformationStore.shared.getHash()
        guard newHash != previousHash else { return }

        let result = await ApiController.putDeviceInformation(info)

        if case .success = result {
            await DeviceInformationStore.shared.setHash(newHash)
        }
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
    
    private func hash(_ request: DeviceInformationRequest) throws -> String {
        let data = try JSONEncoder().encode(request)
        return SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }
}
