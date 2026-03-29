final class TagService: TagServiceProtocol {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func postTags(_ tags: [TagRequest]) async throws {
        let request = APIRequest(
            endpoint: APIEndpoints.tags,
            method: .POST,
            body: tags,
            requiresAuth: true
        )
        try await apiClient.send(request)
    }
}
