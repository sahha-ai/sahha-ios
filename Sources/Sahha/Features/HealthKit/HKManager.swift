import HealthKit

protocol HKManagerProtocol: Actor, DisposableAsync {
    func requestPermissions(for types: Set<HKObjectType>) async throws
    func getAuthorizationStatus(for type: HKObjectType) async -> HKAuthorizationStatus
    func getPermissionStatus(for types: Set<HKObjectType>) async throws -> HKAuthorizationRequestStatus
    func enableBackgroundDelivery(for type: HKObjectType) async throws
    func disableBackgroundDelivery(for type: HKObjectType) async throws
    func startObserverQuery(for type: HKSampleType) async
    func stopObserverQuery(for type: HKSampleType) async
}

actor HKManager: HKManagerProtocol {
    private let anchorStorage: HKAnchorStorageProtocol
    private let healthStore: HKHealthStore
    private let normaliser: HKNormaliserManagerProtocol
    
    private var observerQueries: [HKSampleType: HKObserverQuery] = [:]
    
    init(anchorStorage: HKAnchorStorageProtocol, healthStore: HKHealthStore = HKHealthStore(), normaliser: HKNormaliserManagerProtocol) {
        self.anchorStorage = anchorStorage
        self.healthStore = healthStore
        self.normaliser = normaliser
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
        var shouldContinue = true
        
        while shouldContinue {
            let (samples, newAnchor): ([HKSample], HKQueryAnchor?) = await withCheckedContinuation { continuation in
                let query = HKAnchoredObjectQuery(
                    type: type,
                    predicate: nil,
                    anchor: currentAnchor,
                    limit: 5 // TODO: CHANGE LIMIT AFTER TESTING
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
            
            let normalised = await samples.concurrentFlatMap { sample in
                await self.normaliser.normalise(sample: sample)
            }
            
            for log in normalised { print(log) }
            
            shouldContinue = false;
        }
    }
}

