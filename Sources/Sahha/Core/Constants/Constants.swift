import Foundation

struct Constants {
    static let sdkVersion = "1.0.0"  // Update this as your SDK version changes
    
    struct UserDefaultsKeys {
        // Sensors
        static let enabledSensors = "sahha_enabled_sensors"
        
        // Demographic
        static let demographiclastFetch = "sahha_demographic_last_fetch"
        static let demographicHash = "sahha_demographic_hash"
        
        // Device information
        static let deviceInfoLastSync = "sahha_device_info_last_sync"
        static let deviceInfoDeviceId = "sahha_device_id"
        static let deviceInfoHash = "sahha_device_info_hash"
        
        // HealthKit
        static let healthKitAnchors = "sahha_health_kit_anchors"
    }
    
    struct Keychain {
        static let service = "ai.sahha.ios"
        static let tokenAccount = "sahha_token"
    }
    
    struct Directories {
        static let baseDirectory = getBaseDirectory()
        
        private static func getBaseDirectory() -> URL {
            let fileManager = FileManager.default
            let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let baseURL = appSupportURL.appendingPathComponent("Sahha")
            createDirectoryIfNeeded(at: baseURL)
            excludeFromBackup(url: baseURL)
            return baseURL
        }
        
        private static func createDirectoryIfNeeded(at url: URL) {
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: url.path) {
                try? fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            }
        }
        
        private static func excludeFromBackup(url: URL) {
            var url = url
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try? url.setResourceValues(resourceValues)
        }
    }
}
