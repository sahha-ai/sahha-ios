import Foundation
import UIKit
import CryptoKit

protocol DeviceInfoManagerProtocol: Actor, DisposableAsync {
    func sync() async throws
}

actor DeviceInfoManager: DeviceInfoManagerProtocol {
    private let userDefaults: UserDefaults
    private let deviceInfoService: DeviceInfoServiceProtocol
    private let deviceInfoStore: DeviceInfoStoreProtocol
    private let hashKey = "SahhaDeviceInfoHash"
    
    private var cachedHash: String?
    
    init(userDefaults: UserDefaults = .standard, deviceInfoService: DeviceInfoServiceProtocol, deviceInfoStore: DeviceInfoStoreProtocol) {
        self.userDefaults = userDefaults
        self.deviceInfoService = deviceInfoService
        self.deviceInfoStore = deviceInfoStore
    }
    
    func sync() async throws {
        let deviceInfo = await deviceInfoStore.deviceInfo
        
        if cachedHash == nil {
            cachedHash = try deviceInfo.sha256Hash()
        }
        
        let storedHash = userDefaults.string(forKey: hashKey)
        if storedHash != cachedHash {
            try await deviceInfoService.updateDeviceInformation(deviceInfo)
            userDefaults.set(cachedHash, forKey: hashKey)
        }
    }
    
    func dispose() async {
        userDefaults.removeObject(forKey: hashKey)
        cachedHash = nil
    }
}
