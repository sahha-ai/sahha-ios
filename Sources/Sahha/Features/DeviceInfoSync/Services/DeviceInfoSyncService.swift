final class DeviceInfoSyncService: DeviceInfoSyncServiceProtocol {
    private let apiClient: APIClientProtocol
    
    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }
    
    func syncDeviceInfo(_ deviceInfo: DeviceInfoRequest) async throws {
        let request = APIRequest(
            endpoint: APIEndpoints.deviceInfo,
            method: .PUT,
            body: deviceInfo,
            requiresAuth: true
        )
        try await apiClient.send(request)
    }
}
