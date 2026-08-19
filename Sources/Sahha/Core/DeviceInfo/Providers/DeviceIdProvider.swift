import UIKit

final class DeviceIdProvider: DeviceIdProviderProtocol {
    private let key: String
    private let storage: UserDefaultsStorageProtocol

    init(
        key: String = StorageKeys.UserDefaults.deviceId.rawValue,
        storage: UserDefaultsStorageProtocol
    ) {
        self.key = key
        self.storage = storage
    }
    
    func deviceId() async -> String {
        if let stored = storage.string(forKey: key) {
            return stored
        }
        // Use vendor ID if possible (iOS only)
        #if os(iOS)
        let vendorId = await MainActor.run { UIDevice.current.identifierForVendor?.uuidString }
        #endif
        // Otherwise, generate & persist a new ID
        let newId = vendorId ?? UUID().uuidString
        storage.set(newId, forKey: key)
        return newId
    }
}
