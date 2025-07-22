enum StorageKeys {
    private static let prefix = SDKConfig.prefix

    static let authToken = "\(prefix).AuthToken"

    static let enabledSensors = "\(prefix).EnabledSensors"
    
    static let hkAnchorPrefix = "\(prefix).HKAnchor."
    
    static let demographicCacheHash = "\(prefix).DemographicCacheHash"
    static let demographicCacheTimestamp = "\(prefix).DemographicCacheTimestamp"
    
    static let deviceInfoCacheHash = "\(prefix).DeviceInfoCacheHash"
    static let deviceInfoCacheTimestamp = "\(prefix).DeviceInfoCacheTimestamp"
    
    static let deviceId = "\(prefix).DeviceId"
}
