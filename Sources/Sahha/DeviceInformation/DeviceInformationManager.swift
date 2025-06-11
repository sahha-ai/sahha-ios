import Foundation
import UIKit
import CryptoKit

final actor DeviceInformationManager {
    static let shared = DeviceInformationManager()
    
    private var isSycning = false
    
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
        guard !isSycning else { return }
        
        isSycning = true
        defer { isSycning = false }
        
        let info = await collect()
        
        guard let newHash = try? hash(info) else {
            SahhaLogger.error("Failed to hash device information")
            return
        }
        
        let previousHash = await DeviceInformationStore.shared.getHash()
        guard newHash != previousHash else {
            SahhaLogger.info("Device information hasn't changed, skipping sync")
            return
        }
        
        let result = await ApiController.putDeviceInformation(info)
        
        switch result {
        case .success:
            SahhaLogger.info("Device information synced successfully")
            await DeviceInformationStore.shared.setHash(newHash)
        case .failure(let error):
            SahhaLogger.error("Failed to sync device information: \(error)")
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
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(request)
        return SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }
}
