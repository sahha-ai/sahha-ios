import Foundation

protocol DemographicServiceProtocol: Actor {
    
}

// TODO: Implementation

actor DemographicService: DemographicServiceProtocol {
    private let apiService: SecureAPIServiceProtocol
    
    init(apiService: SecureAPIServiceProtocol) {
        self.apiService = apiService
    }
}
