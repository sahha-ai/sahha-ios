import Foundation

enum ApiController {
    // MARK: Authentication
    
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
    
    // MARK: Device Information
    
    static func putDeviceInformation(_ deviceInformation: DeviceInformationRequest) async -> Result<Void, SahhaError> {
        let endpoint = PutDeviceInformationEndpoint(request: deviceInformation)
        return await ApiClient.shared.send(endpoint)
    }
    
    // MARK: Demographic
    
    static func getDemographic() async -> Result<SahhaDemographicResponse, SahhaError> {
        let endpoint = GetDemographicEndpoint()
        return await ApiClient.shared.send(endpoint, responseType: SahhaDemographicResponse.self)
    }

    static func patchDemographic(_ demographic: SahhaDemographicRequest) async -> Result<Void, SahhaError> {
        let endpoint = PatchDemographicEndpoint(request: demographic)
        return await ApiClient.shared.send(endpoint)
    }
    
    // MARK: Scores
    
    static func getScores(types: Set<String>, startDateTime: Date, endDateTime: Date) async -> Result<[ScoreResponse], SahhaError> {
        let endpoint = GetScoresEndpoint(types: types, startDateTime: startDateTime, endDateTime: endDateTime)
        return await ApiClient.shared.send(endpoint, responseType: [ScoreResponse].self)
    }
    
    // MARK: Biomarkers
    
    static func getBiomarkers(categroies: Set<String>, types: Set<String>, startDateTime: Date, endDateTime: Date) async -> Result<[BiomarkerResponse], SahhaError> {
        let endpoint = GetBiomarkersEndpoint(categories: categroies, types: types, startDateTime: startDateTime, endDateTime: endDateTime)
        return await ApiClient.shared.send(endpoint, responseType: [BiomarkerResponse].self)
    }
    
    // MARK: Errors
    
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
