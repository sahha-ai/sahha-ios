import HealthKit

final actor HKQueryManager {
    static let shared = HKQueryManager()
    
    private init() {}
    
    private let healthStore = HKHealthStore()
    
    func startObserverQuery(for sampleType: HKSampleType) {
        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { _, completionHandler, error in
            if let error = error {
                print("Observer query error for \(sampleType.identifier): \(error.localizedDescription)")
                completionHandler()
                return
            }
            
            Task {
                if let sensor = SahhaSensor.from(sampleType: sampleType),
                   await SensorStore.shared.isEnabled(sensor) {
                    await self.runAnchorQuery(for: sampleType)
                }
            }
            
            completionHandler()
        }
        
        healthStore.execute(query)
    }
    
    private func runAnchorQuery(for sampleType: HKSampleType) async {
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
            }
            
            let logs = await samples.concurrentFlatMap { $0.toDataLogs() }
            let result = await DataLogManager.shared.ingest(logs)
            
            switch result {
            case .success, .batchingPaused:
                if let newAnchor = newAnchor {
                    await HKAnchorStore.shared.saveAnchor(newAnchor, for: sampleType)
                    currentAnchor = newAnchor
                }
                shouldContinue = (result == .success) && !samples.isEmpty
            case .storageFailed:
                print("Storage failed — halting queries to preserve anchor")
                shouldContinue = false
            }
        }
    }
}
