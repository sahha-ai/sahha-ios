import Foundation

protocol DeviceInfoServiceProtocol: Actor {
    func sync() async throws
}

actor DeviceInfoService: DeviceInfoServiceProtocol {
    private let apiService: SecureAPIServiceProtocol
    private let deviceInfoManager: DeviceInfoManagerProtocol
    
    init(apiService: SecureAPIServiceProtocol, deviceInfoManager: DeviceInfoManagerProtocol) {
        self.apiService = apiService
        self.deviceInfoManager = deviceInfoManager
    }
    
    func sync() async throws {
        let deviceInfo = await deviceInfoManager.getDeviceInfo()
        guard try await deviceInfoManager.hasDeviceInfoChanged() else {
            // No changes, skip sync
            return
        }
        
        let endpoint = PutDeviceInfoEndpoint(request: deviceInfo)
        try await apiService.send(endpoint)
        try await deviceInfoManager.saveDeviceInfoHash()
    }
}
