protocol DeviceServiceProtocol: Sendable {
    func updateDeviceInformation(_ deviceInformation: DeviceInformation) async throws
}

final class DeviceService: DeviceServiceProtocol {
    private let apiService: APIServiceProtocol

    init(apiService: APIServiceProtocol) {
        self.apiService = apiService
    }
    
    func updateDeviceInformation(_ deviceInformation: DeviceInformation) async throws {
        let request = APIRequest(
            endpoint: Constants.Endpoints.deviceInformation,
            method: .PUT,
            body: deviceInformation
        )
        try await apiService.send(request)
    }
}
