protocol DeviceInfoSyncCacheProtocol: Actor {
    func cacheDeviceInfo(_ deviceInfo: DeviceInfo)
    func needsSync(comparedTo deviceInfo: DeviceInfo) -> Bool
}
