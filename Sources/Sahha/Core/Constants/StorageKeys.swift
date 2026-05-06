enum StorageKeys {
    enum UserDefaults {
        static let deviceId = "deviceId"
        static let deviceInfo = "deviceInfo"
        static let sensors = "sensors"
        static let hkAnchorPrefix = "hkAnchor."
        static let hkAnchorDatePrefix = "hkAnchorDate."
        static let sentLogIds = "sentLogIds"
        static let sentTagIds = "sentTagIds"
    }
    
    enum Keychain {
        static let service = "ai.sahha.ios"
        static let token = "token"
        static let demographic = "demographic"
    }
}
