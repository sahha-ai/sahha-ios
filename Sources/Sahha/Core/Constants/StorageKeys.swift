//
//  StorageKeys.swift
//  Sahha
//
//  Created by Connor Cain on 21/07/2025.
//

enum StorageKeys {
    enum UserDefaults {
        private static let prefix = "ai.sahha."
        
        static let deviceInfoStateKey = prefix + "deviceInfoState"
        static let demographicStateKey = prefix + "demographicState"
        static let enabledSensorsKey = prefix + "enabledSensors"
        static let hkAnchorPrefix = prefix + "hkAnchor."
    }
    
    enum Keychain {
        static let service = "ai.sahha.sdk"
        
        static let deviceIdKey = "deviceId"
        static let tokenResponseKey = "tokenResponse"
    }
}
