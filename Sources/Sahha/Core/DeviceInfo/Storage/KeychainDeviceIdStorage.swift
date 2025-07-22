import UIKit

final actor KeychainDeviceIdStorage: DeviceIdStoring {
    private let storage: KeychainStoring
    private let key = StorageKeys.Keychain.deviceIdKey
    private let logger: ErrorLogger
    
    private var cached: String?

    init(storage: KeychainStoring = KeychainStorage(), logger: ErrorLogger) {
        self.storage = storage
        self.logger = logger
    }

    func getDeviceId() async throws -> String {
        // Try return in memory cached id
        if let id = cached {
            return id
        }
        
        // Try to read existing from keychain
        if let existingData = try await storage.get(forKey: key),
            let existing = String(data: existingData, encoding: .utf8),
            !existing.isEmpty
        {
            return existing
        }

        // Fallback to a fresh UUID
        let newId = await UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        if let data = newId.data(using: .utf8) {
            try await storage.set(data, forKey: key)
        }
        cached = newId
        return newId
    }
}
