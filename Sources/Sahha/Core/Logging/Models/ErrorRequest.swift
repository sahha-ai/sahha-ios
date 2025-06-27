struct ErrorRequest: Codable {
    let sdkId: String?
    let sdkVersion: String?
    let appId: String?
    let appVersion: String?
    let deviceId: String?
    let deviceType: String?
    let deviceModel: String?
    let system: String?
    let systemVersion: String?
    let errorSource: String?
    let errorCode: Int?
    let errorLocation: String?
    let errorMessage: String?
    let errorBody: String?
    let codePath: String?
    let codeMethod: String?
    let codeBody: String?
}
