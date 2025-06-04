final actor ConfigurationStore {
    static let shared = ConfigurationStore()
    
    private init() {}
    
    private var cached: SahhaSettings?
    
    func getEnvironment() -> SahhaEnvironment? {
        cached?.environment
    }
    
    func getFramework() -> SahhaFramework? {
        cached?.framework
    }
    
    func set(_ settings: SahhaSettings) {
        cached = settings
    }
}
