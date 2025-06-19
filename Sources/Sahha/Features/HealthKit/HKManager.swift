import HealthKit

protocol HKManagerProtocol: Actor, DisposableAsync {
    func requestPermissions(for types: Set<HKObjectType>) async throws
//    func getAuthorizationStatus(for type: HKObjectType) async -> HKAuthorizationStatus // For potential future use?
    func getPermissionStatus(for types: Set<HKObjectType>) async throws -> HKAuthorizationRequestStatus
    func enableBackgroundDelivery(for type: HKObjectType) async throws
    func disableBackgroundDelivery(for type: HKObjectType) async throws
    func startObserverQuery(for type: HKSampleType) async
    func stopObserverQuery(for type: HKSampleType) async
}

actor HKManager: HKManagerProtocol {
    private let anchorStorage: HKAnchorStorageProtocol
    private let healthStore: HKHealthStore
    private let normalisers: [HKSampleType: any HKNormaliser]
    private let processor: any DataLogProcessorProtocol
    
    private var observerQueries: [HKSampleType: HKObserverQuery] = [:] // Track running observers
    private var anchorQueryTasks: [HKSampleType: Task<Void, Never>] = [:] // Track running tasks
    
    init(
        anchorStorage: HKAnchorStorageProtocol,
        healthStore: HKHealthStore = HKHealthStore(),
        normalisers: [HKSampleType:  any HKNormaliser],
        processor: any DataLogProcessorProtocol
    ) {
        self.anchorStorage = anchorStorage
        self.healthStore = healthStore
        self.normalisers = normalisers
        self.processor = processor
    }
    
    func requestPermissions(for types: Set<HKObjectType>) async throws {
        try await healthStore.requestAuthorization(toShare: [], read: types)
    }
    
    // For potential future use?
//    func getAuthorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
//        return healthStore.authorizationStatus(for: type)
//    }
    
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
                await self.runAnchorQueryIfNeeded(for: type)
            }
            completionHandler()
        }
        observerQueries[type] = query
        healthStore.execute(query)
    }
    
    private func runAnchorQueryIfNeeded(for type: HKSampleType) async {
        if anchorQueryTasks[type] == nil {
            let task = Task {
                await self.runAnchorQuery(for: type)
            }
            anchorQueryTasks[type] = task
        }
    }
    
    func stopObserverQuery(for type: HKSampleType) async {
        if let query = observerQueries[type] {
            healthStore.stop(query)
            observerQueries.removeValue(forKey: type)
        }
        if let task = anchorQueryTasks[type] {
            task.cancel()
            anchorQueryTasks.removeValue(forKey: type)
        }
    }
    
    func dispose() async {
        // Cancel all running anchor query tasks
        for task in anchorQueryTasks.values {
            task.cancel()
        }
        anchorQueryTasks.removeAll()
        
        // Stop all observer queries
        for query in observerQueries.values {
            healthStore.stop(query)
        }
        observerQueries.removeAll()
        
        // Delete anchors
        anchorStorage.deleteAnchors()
    }
    
    private func runAnchorQuery(for type: HKSampleType) async {
        defer { anchorQueryTasks[type] = nil } // Remove the task when done
        
        var currentAnchor = anchorStorage.getAnchor(for: type)
        
        // Fetch batches only while the processor is accepting data
        while await processor.isAcceptingData() {
            // Fetch samples using HKAnchoredObjectQuery
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
            
            // If no samples are returned, we’ve fetched everything
            if samples.isEmpty {
                break
            }
            
            // Normalize the samples
            let normalised = await samples.concurrentFlatMap { sample in
                if let normaliser = self.normalisers[sample.sampleType] {
                    return await normaliser.normalise(sample)
                }
                return []
            }
            
            // Wait for the processor to accept data, with up to 3 retries
            if await waitForProcessorToAcceptData(maxRetries: 3, delay: 1.0) {
                do {
                    // Process the normalized data
                    try await processor.processData(normalised)
                    // Update the anchor if a new one is provided
                    if let newAnchor = newAnchor {
                        currentAnchor = newAnchor
                        anchorStorage.setAnchor(newAnchor, for: type)
                    }
                } catch {
                    print("Error processing data: \(error.localizedDescription)")
                    break // Stop on processing error
                }
            } else {
                print("Processor not accepting data after 3 retries, stopping.")
                break // Stop if retries fail
            }
        }
    }
    
    private func waitForProcessorToAcceptData(maxRetries: Int, delay: TimeInterval) async -> Bool {
        var attempts = 0
        while attempts < maxRetries {
            if await processor.isAcceptingData() {
                return true
            }
            // Wait for the specified delay before the next attempt
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            attempts += 1
        }
        return await processor.isAcceptingData() // Final check after retries
    }
}

