import Foundation

final actor DeviceInformationStore {
    static let shared = DeviceInformationStore()
    
    private let hashStorage = UserDefaultsStorage<String>(key: "ai.sahha.ios.device-info-hash")
    private var cachedHash: String?
    private var cachedInfo: DeviceInformationRequest?
    
    private init() {
        self.cachedHash = hashStorage.get()
    }
    
    func getHash() -> String? {
        return cachedHash
    }
    
    func setHash(_ hash: String) {
        cachedHash = hash
        hashStorage.set(hash)
    }
    
    func getInfo() async -> DeviceInformationRequest {
        if let info = cachedInfo {
            return info
        }

        let info = await DeviceInformationManager.shared.collect()
        cachedInfo = info
        return info
    }
    
    func clear() {
        cachedHash = nil
        hashStorage.delete()
    }
}
