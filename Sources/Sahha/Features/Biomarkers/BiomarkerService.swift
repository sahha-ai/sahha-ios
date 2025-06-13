import Foundation

protocol BiomarkerServiceProtocol: Actor {
    func getBiomarkers(categories: Set<String>, types: Set<String>, startDateTime: Date, endDateTime: Date) async throws -> [BiomarkerResponse]
}

actor BiomarkerService: BiomarkerServiceProtocol {
    private let apiService: SecureAPIServiceProtocol
    
    init(apiService: SecureAPIServiceProtocol) {
        self.apiService = apiService
    }
    
    func getBiomarkers(categories: Set<String>, types: Set<String>, startDateTime: Date, endDateTime: Date) async throws -> [BiomarkerResponse] {
        guard !categories.isEmpty else {
            throw ValidationError.emptyCollection(collection: "Categories")
        }
        guard !types.isEmpty else {
            throw ValidationError.emptyCollection(collection: "Types")
        }
        guard startDateTime <= endDateTime else {
            throw ValidationError.invalidDateRange
        }
        
        let endpoint = GetBiomarkersEndpoint(categories: categories, types: types, startDateTime: startDateTime, endDateTime: endDateTime)
        return try await apiService.send(endpoint, as: [BiomarkerResponse].self)
    }
}
