final class DefaultDeviceInfoService: DeviceInfoService {
    private let api: APIClient
    
    init(api: APIClient) {
        self.api = api
    }
    
    func updateDeviceInfo(_ info: DeviceInformation) async throws {
        let request = APIRequest(
            endpoint: APIEndpoints.deviceInfo,
            method: .PUT,
            body: info,
            requiresAuth: true
        )
        try await api.send(request)
    }
}
