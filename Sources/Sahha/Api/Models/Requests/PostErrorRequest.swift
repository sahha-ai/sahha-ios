struct PostErrorRequest: Encodable {
   var sdkId: String?
   var sdkVersion: String?
   var appId: String?
   var appVersion: String?
   var deviceId: String?
   var deviceType: String?
   var deviceModel: String?
   var system: String?
   var systemVersion: String?
   var errorSource: String?
   var errorCode: Int?
   var errorLocation: String?
   var errorMessage: String?
   var errorBody: String?
   var codePath: String?
   var codeMethod: String?
   var codeBody: String?
   var timeZone: String?
}
