import UIKit

final actor DefaultDeviceIdStore: DeviceIdStore {
    private let secureStore: SecureStore
    private let storageKey = StorageKeys.deviceId

    private var cachedId: String?

    init(secureStore: SecureStore = KeychainStore()) {
        self.secureStore = secureStore
    }

    func getId() async -> String {
        if let id = cachedId {
            return id
        }
        if let stored: String = try? await secureStore.get(storageKey) {
            return stored
        }
        let newId = await UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        try? await secureStore.set(newId, forKey: storageKey)
        cachedId = newId
        return newId
    }
}
