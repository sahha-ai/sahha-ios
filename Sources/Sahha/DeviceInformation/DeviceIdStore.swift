import UIKit

final actor DeviceIdStore {
    static let shared = DeviceIdStore()
    
    private let storage = UserDefaultsStorage<String>(key: "ai.sahha.ios.device-id")
    private var cached: String?
    
    private init() {
        self.cached = storage.get()
    }
    
    func getDeviceId() async -> String {
        if let cached = cached {
            return cached
        }
        
        let generated = await MainActor.run {
            UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        }
        
        cached = generated
        storage.set(generated)
        
        return generated
    }
}
