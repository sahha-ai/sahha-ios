extension APIRequest {
    static func updateDeviceInfo(_ info: DeviceInformation) -> APIRequest {
        APIRequest(
            endpoint: APIEndpoints.deviceInfo,
            method: .PUT,
            body: info,
            requiresAuth: true
        )
    }
}
