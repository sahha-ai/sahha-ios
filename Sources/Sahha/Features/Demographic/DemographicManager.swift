import Foundation
import UIKit
import CryptoKit

protocol DemographicManagerProtocol: Actor {
    func getDemographic() async throws -> DemographicResponse
    func updateDemographic() async throws
    func clear() async throws
}

enum DemographicError: Error, LocalizedError {
    case missingDemographic
    
    var errorDescription: String? {
        switch self {
        case .missingDemographic:
            return "Demographic data is not available."
        }
    }
}

actor DemographicManager: DemographicManagerProtocol {
    private let userDefaults: UserDefaults
    private let demographicService: DemographicServiceProtocol
    
    private var cachedDemographic: DemographicResponse?
    private var cachedHash: String?
    
    private let hashKey = "SahhaDemographicHash"
    
    init(userDefaults: UserDefaults, demographicSerivce: DemographicServiceProtocol) {
        self.userDefaults = userDefaults
        self.demographicService = demographicSerivce
    }
    
    func getDemographic() async throws -> DemographicResponse {
        if let cached = cachedDemographic {
            return cached
        }
        
        let demographic = try await demographicService.getDemographic()
        cachedDemographic = demographic
        do {
            cachedHash = try demographic.sha256Hash()
        } catch {
            print("Failed to hash demographic: \(error)")
            cachedHash = nil
        }
        return demographic
    }
    
    func updateDemographic() async throws {
        let demographic = try await getDemographic()
        
        guard let currentHash = cachedHash else {
            throw DemographicError.missingDemographic
        }
        
        let storedHash = userDefaults.string(forKey: hashKey)
        if storedHash != currentHash {
            let request = DemographicRequest(from: demographic)
            try await demographicService.updateDemographic(request)
            userDefaults.set(currentHash, forKey: hashKey)
        }
    }
    
    func clear() async {
        userDefaults.removeObject(forKey: hashKey)
        cachedDemographic = nil
        cachedHash = nil
    }
}
