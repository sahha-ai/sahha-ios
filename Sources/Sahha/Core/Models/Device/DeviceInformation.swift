struct DeviceInformation: Encodable {
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
