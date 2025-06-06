import Foundation

actor DemographicStore {
    static let shared = DemographicStore()
    
    private let storage = KeychainStorage<SahhaDemographic>(account: "ai.sahha.ios.demographic")
    private var cached: SahhaDemographic?
    
    private init() {
        self.cached = storage.get()
    }

    func set(_ demographic: SahhaDemographic) throws {
        guard storage.set(demographic) else {
            throw SahhaError.custom(message: "An error occurred while storing demographic")
        }
        cached = demographic
    }

    func get() -> SahhaDemographic? {
        cached
    }

    func clear() throws {
        guard storage.delete() else {
            throw SahhaError.custom(message: "An error occurred while deleting demographic")
        }
        cached = nil
    }
}
