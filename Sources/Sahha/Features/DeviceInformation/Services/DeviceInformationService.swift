final class DeviceInformationService: DeviceInformationServiceProtocol {
    private let apiService: APIServiceProtocol

    init(apiService: APIServiceProtocol) {
        self.apiService = apiService
    }
    
    func updateDeviceInformation(_ deviceInformation: DeviceInformation) async throws {
        let request = APIRequest(
            endpoint: "v1/profile/deviceInformation",
            method: .PUT,
            body: deviceInformation
        )
        try await apiService.request(request)
    }
}
