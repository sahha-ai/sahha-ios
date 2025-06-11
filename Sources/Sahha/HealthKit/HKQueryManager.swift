import HealthKit

final actor HKQueryManager {
    static let shared = HKQueryManager()
    
    private init() {}
    
    private let healthStore = HKHealthStore()
    
    private var runningAnchorQueries: [HKSampleType: HKQuery] = [:]
    private var runningObserverQueries: [HKSampleType: HKObserverQuery] = [:]
    private var isResetting = false
    
    func startObserverQuery(for sampleType: HKSampleType) {
        guard !isResetting else { return }
        
        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { _, completionHandler, error in
            if let error = error {
                print("Observer query error for \(sampleType.identifier): \(error.localizedDescription)")
                completionHandler()
                return
            }
            
            Task {
                await self.runAnchorQuery(for: sampleType)
            }
            
            completionHandler()
        }
        
        healthStore.execute(query)
        runningObserverQueries[sampleType] = query
    }
    
    func stopObserverQuery(for sampleType: HKSampleType) async {
        if let query = runningObserverQueries[sampleType] {
            healthStore.stop(query)
            runningObserverQueries.removeValue(forKey: sampleType)
            SahhaLogger.info("Stopped observer query for \(sampleType.identifier)")
        }
    }
    
    func stopAnchorQuery(for sampleType: HKSampleType) async {
        if let query = runningAnchorQueries[sampleType] {
            healthStore.stop(query)
            runningAnchorQueries.removeValue(forKey: sampleType)
            SahhaLogger.info("Stopped anchor query for \(sampleType.identifier)")
        }
    }
    
    func stopAllQueries() async {
        isResetting = true
        
        for (sampleType, query) in runningObserverQueries {
            healthStore.stop(query)
            SahhaLogger.info("Stopped observer query for \(sampleType.identifier)")
        }
        runningObserverQueries.removeAll()
        
        for (sampleType, query) in runningAnchorQueries {
            healthStore.stop(query)
            SahhaLogger.info("Stopped anchor query for \(sampleType.identifier)")
        }
        runningAnchorQueries.removeAll()
        
        SahhaLogger.info("All HealthKit queries stopped")
        isResetting = false
    }
    
    private func runAnchorQuery(for sampleType: HKSampleType) async {
        guard !isResetting else { return }
        
        var currentAnchor: HKQueryAnchor? = await HKAnchorStore.shared.loadAnchor(for: sampleType)
        var shouldContinue = true
        
        while shouldContinue {
            let (samples, newAnchor): ([HKSample], HKQueryAnchor?) = await withCheckedContinuation { continuation in
                let query = HKAnchoredObjectQuery(
                    type: sampleType,
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
                self.runningAnchorQueries[sampleType] = query
            }
            
            guard !isResetting else { break }
            
            let logs = await samples.concurrentFlatMap { $0.toDataLogs() }
            SahhaLogger.info("Received \(logs.count) logs from anchor query for \(sampleType)")
            
            var result: BatchIngestionResult = .batchingPaused
            
            let backoffDelays: [UInt64] = [2, 5, 10].map { $0 * 1_000_000_000 }
            var retries = 0
            
            repeat {
                result = await DataLogManager.shared.ingest(logs)
                SahhaLogger.info("Result of anchor query for \(sampleType): \(result)")
                
                switch result {
                case .success:
                    if let newAnchor = newAnchor {
                        await HKAnchorStore.shared.saveAnchor(newAnchor, for: sampleType)
                        currentAnchor = newAnchor
                    }
                    shouldContinue = !samples.isEmpty
                    break
                    
                case .batchingPaused:
                    if let newAnchor = newAnchor {
                        await HKAnchorStore.shared.saveAnchor(newAnchor, for: sampleType)
                        currentAnchor = newAnchor
                    }
                    
                    if retries < backoffDelays.count {
                        let delay = backoffDelays[retries]
                        SahhaLogger.warning("Batching paused — waiting \(delay / 1_000_000_000)s before retry")
                        try? await Task.sleep(nanoseconds: delay)
                        retries += 1
                    } else {
                        SahhaLogger.warning("Max retries reached — exiting query loop")
                        shouldContinue = false
                        break
                    }
                    
                case .storageFailed:
                    SahhaLogger.error("Storage failed — halting queries to preserve anchor")
                    shouldContinue = false
                    break
                    
                }
            } while retries <= backoffDelays.count && result == .batchingPaused
        }
        
        runningAnchorQueries.removeValue(forKey: sampleType)
    }
}
