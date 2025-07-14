import Foundation
import UIKit

protocol DeviceIdStore: Actor {
    func getDeviceId() async -> String
}

final actor DeviceIdStoreImpl: DeviceIdStore {
    private let key: String

    init(key: String = Constants.UserDefaultsKeys.DeviceInformation.deviceId) {
        self.key = key
    }

    private var deviceId: String?

    func getDeviceId() async -> String {
        if let cached = deviceId {
            return cached
        }
        if let stored = UserDefaults.standard.string(forKey: key) {
            deviceId = stored
            return stored
        }
        let new = await UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        deviceId = new
        UserDefaults.standard.set(new, forKey: key)
        return new
    }
}
