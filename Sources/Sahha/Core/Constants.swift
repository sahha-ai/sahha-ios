import Foundation

struct Constants {
    static let sdkVersion = "1.0.0"  // Update this when SDK version changes

    struct UserDefaultsKeys {
        struct Sensors {
            static let enabledSensors = "sahha_enabled_sensors"
        }

        struct Demographic {
            static let lastFetch = "sahha_demographic_last_fetch"
            static let hash = "sahha_demographic_hash"
        }

        struct DeviceInformation {
            static let deviceId = "sahha_device_id"
            static let lastFetch = "sahha_device_information_last_fetch"
            static let hash = "sahha_device_information_hash"
        }

        struct HealthKit {
            static let anchors = "sahha_health_kit_anchors"
        }
    }

    struct Keychain {
        static let service = "ai.sahha.ios"

        struct Token {
            static let account = "sahha_token"
        }
    }

    struct Endpoints {
        static let error = "v1/error"
        static let registerProfile = "v1/oauth/profile/register/appId"
        static let refreshToken = "v1/oauth/profile/refreshToken"
        static let deviceInformation = "v1/profile/deviceInformation"
        static let demographic = "v1/profile/demographic"
        static let score = "v1/profile/score"
        static let biomarker = "v1/profile/biomarker"
        static let dataLog = "v1/profile/data/log"
    }

    struct Directories {
        static let baseDirectory = getBaseDirectory()
        
        static let dataLogBatches: URL = {
            let url = baseDirectory
                .appendingPathComponent("DataLogs", isDirectory: true)
                .appendingPathComponent("Batches", isDirectory: true)
            createDirectoryIfNeeded(at: url)
            return url
        }()

        private static func getBaseDirectory() -> URL {
            let fileManager = FileManager.default
            let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let baseURL = appSupportURL.appendingPathComponent("Sahha")
            createDirectoryIfNeeded(at: baseURL)
            excludeFromBackup(url: baseURL)
            
            print(baseURL)
            
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
