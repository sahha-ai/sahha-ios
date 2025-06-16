import Foundation

protocol DeviceInfoServiceProtocol: Actor {
    func updateDeviceInformation(_ request: DeviceInfoRequest) async throws
}

actor DeviceInfoService: DeviceInfoServiceProtocol {
    private let apiService: SecureAPIServiceProtocol
    
    init(apiService: SecureAPIServiceProtocol) {
        self.apiService = apiService
    }
    
    func updateDeviceInformation(_ request: DeviceInfoRequest) async throws {
        let endpoint = PutDeviceInfoEndpoint(request: request)
        try await apiService.send(endpoint)
    }
}
