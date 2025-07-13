protocol DeviceInformationService: Sendable {
    func updateDeviceInformation(_ deviceInformation: DeviceInformation) async throws
}

final class DeviceInformationServiceImpl: DeviceInformationService {
    private let api: APIService

    init(api: APIService) {
        self.api = api
    }

    func updateDeviceInformation(_ deviceInformation: DeviceInformation) async throws {
        let request = APIRequest(
            endpoint: Constants.Endpoints.deviceInformation,
            method: .PUT,
            body: deviceInformation
        )
        try await api.send(request)
    }
}
