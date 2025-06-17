import HealthKit

protocol HealthKitManagerProtocol: Actor, DisposableAsync {
    func requestPermissions(for types: Set<HKObjectType>) async throws
    func getAuthorizationStatus(for type: HKObjectType) async -> HKAuthorizationStatus
    func getPermissionStatus(for types: Set<HKObjectType>) async throws -> HKAuthorizationRequestStatus
    func enableBackgroundDelivery(for type: HKObjectType) async throws
    func disableBackgroundDelivery(for type: HKObjectType) async throws
    func startObserverQuery(for type: HKSampleType) async
    func stopObserverQuery(for type: HKSampleType) async
}

actor HealthKitManager: HealthKitManagerProtocol {
    private let anchorStorage: HealthKitAnchorStorageProtocol
    private let healthStore: HKHealthStore
    private var observerQueries: [HKSampleType: HKObserverQuery] = [:]
    
    init(anchorStorage: HealthKitAnchorStorageProtocol, healthStore: HKHealthStore = HKHealthStore()) {
        self.anchorStorage = anchorStorage
        self.healthStore = healthStore
    }
    
    func requestPermissions(for types: Set<HKObjectType>) async throws {
        try await healthStore.requestAuthorization(toShare: [], read: types)
    }
    
    func getAuthorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        return healthStore.authorizationStatus(for: type)
    }
    
    func getPermissionStatus(for types: Set<HKObjectType>) async throws -> HKAuthorizationRequestStatus {
        try await healthStore.statusForAuthorizationRequest(toShare: [], read: types)
    }
    
    func enableBackgroundDelivery(for type: HKObjectType) async throws {
        try await healthStore.enableBackgroundDelivery(for: type, frequency: .immediate)
    }
    
    func disableBackgroundDelivery(for type: HKObjectType) async throws {
        try await healthStore.disableBackgroundDelivery(for: type)
    }
    
    func startObserverQuery(for type: HKSampleType) async {
        guard !observerQueries.keys.contains(type) else { return }
        
        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completionHandler, error in
            guard let self = self else { return }
            if let error = error {
                print("Observer query error: \(error)")
                return
            }
            Task {
                await self.runAnchorQuery(for: type)
            }
            completionHandler()
        }
        observerQueries[type] = query
        healthStore.execute(query)
    }
    
    func stopObserverQuery(for type: HKSampleType) async {
        if let query = observerQueries[type] {
            healthStore.stop(query)
            observerQueries.removeValue(forKey: type)
        }
    }
    
    func dispose() async {
        for query in observerQueries.values {
            healthStore.stop(query)
        }
        observerQueries.removeAll()
        anchorStorage.deleteAnchors()
    }
    
    private func runAnchorQuery(for type: HKSampleType) async {
        var currentAnchor = anchorStorage.getAnchor(for: type)
        var shouldContinue = false
        
        repeat {
            let (samples, newAnchor): ([HKSample], HKQueryAnchor?) = await withCheckedContinuation { continuation in
                let query = HKAnchoredObjectQuery(
                    type: type,
                    predicate: nil,
                    anchor: currentAnchor,
                    limit: 500
                ) { _, samplesOrNil, _, newAnchor, error in
                    if let error = error {
                        print("Anchor query failed: \(error)")
                        continuation.resume(returning: ([], nil))
                        return
                    }
                    
                    continuation.resume(returning: (samplesOrNil ?? [], newAnchor))
                }
                
                healthStore.execute(query)
            }
            
            // TODO: Normalize samples to DataLog
            // TODO: Ingest DataLogs into DataLogManager
            // TODO: Repeat n times until ingestion succeeds for fails
            // TODO: Save anchor on successful ingestion
        } while shouldContinue
    }
}

