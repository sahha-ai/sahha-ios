struct DeviceInfoRequest: Encodable, Sendable {
    let sdkId: String
    let sdkVersion: String
    let appId: String
    let appVersion: String
    let deviceId: String
    let deviceType: String
    let deviceModel: String
    let system: String
    let systemVersion: String
    let timeZone: String
}

extension DeviceInfoRequest {
    init(_ deviceInfo: DeviceInfo) {
        self.sdkId = deviceInfo.sdkId
        self.sdkVersion = deviceInfo.sdkVersion
        self.appId = deviceInfo.appId
        self.appVersion = deviceInfo.appVersion
        self.deviceId = deviceInfo.deviceId
        self.deviceType = deviceInfo.deviceType
        self.deviceModel = deviceInfo.deviceModel
        self.system = deviceInfo.system
        self.systemVersion = deviceInfo.systemVersion
        self.timeZone = deviceInfo.timeZone
    }
}
