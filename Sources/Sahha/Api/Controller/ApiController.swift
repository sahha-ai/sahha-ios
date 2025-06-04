import Foundation

enum ApiController {
    
    static func registerProfile(appId: String, appSecret: String, externalId: String) async -> Result<TokenResponse, SahhaError> {
        let request = RegisterProfileRequest(externalId: externalId)
        let endpoint = RegisterProfileEndpoint(request: request, appId: appId, appSecret: appSecret)
        return await ApiClient.shared.send(endpoint, responseType: TokenResponse.self)
    }
    
    static func refreshToken(_ refreshToken: String) async -> Result<TokenResponse, SahhaError> {
        let request = RefreshTokenRequest(refreshToken: refreshToken)
        let endpoint = RefreshTokenEndpoint(request: request)
        return await ApiClient.shared.send(endpoint, responseType: TokenResponse.self)
    }
    
    static func putDeviceInformation(_ deviceInformation: DeviceInformationRequest) async -> Result<Void, SahhaError> {
        let endpoint = PutDeviceInformationEndpoint(request: deviceInformation)
        return await ApiClient.shared.send(endpoint)
    }
    
    static func postError(
        source: String = "sdk",
        code: Int? = nil,
        location: String? = nil,
        message: String? = nil,
        error: Error? = nil,
        body: String? = nil,
        codePath: String? = nil,
        codeMethod: String? = nil,
        codeBody: String? = nil) async {
            Task.detached {
                let deviceInfo = await DeviceInformationStore.shared.getInfo()
                
                let merged = PostErrorRequest(
                    sdkId: deviceInfo.sdkId,
                    sdkVersion: deviceInfo.sdkVersion,
                    appId: deviceInfo.appId,
                    appVersion: deviceInfo.appVersion,
                    deviceId: deviceInfo.deviceId,
                    deviceType: deviceInfo.deviceType,
                    deviceModel:  deviceInfo.deviceModel,
                    system:  deviceInfo.system,
                    systemVersion: deviceInfo.systemVersion,
                    errorSource: source,
                    errorCode: code,
                    errorLocation: location,
                    errorMessage: message,
                    errorBody: body,
                    codePath: codePath,
                    codeMethod: codeMethod,
                    codeBody: codeBody
                )
                
                let endpoint = PostErrorEndpoint(request: merged)
                _ = await ApiClient.shared.send(endpoint)
            }
        }
}
