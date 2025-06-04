import HealthKit

final actor HKManager {
    static let shared = HKManager()
    
    private init() {}
    
    private let healthStore = HKHealthStore()
    private var activeSensors: Set<HKObjectType> = []
    
    func startSensors(maxConcurrentTasks: Int = 4) async {
        let sensors = await SensorStore.shared.getEnabledSensors()
        let semaphore = AsyncSemaphore(value: maxConcurrentTasks)
        
        await withTaskGroup(of: Void.self) { group in
            for sensor in sensors {
                group.addTask {
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }
                    await self.startSensor(sensor)
                }
            }
        }
    }
    
    private func startSensor(_ sensor: SahhaSensor) async {
        guard let sampleType = sensor.hkSampleType else { return }
        
        // Skip if already observing
        guard !self.activeSensors.contains(sampleType) else { return }
        
        self.activeSensors.insert(sampleType)
        self.startObserverQuery(for: sampleType)
        await self.enableBackgroundDelivery(for: sampleType)
    }
    
    private func startObserverQuery(for sampleType: HKSampleType) {
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
    
    private func enableBackgroundDelivery(for sampleType: HKSampleType) async {
        do {
            try await healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate)
        } catch {
            if let sensor = SahhaSensor.from(sampleType: sampleType) {
                print("Failed to enable background delivery for \(sensor)")
            } else {
                print("Failed to enable background delivery for \(sampleType)")
            }
        }
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
                    limit: 50_000
                ) { _, samplesOrNil, _, newAnchor, error in
                    if let error = error {
                        print("Anchor query failed: \(error)")
                        continuation.resume(returning: ([], nil)) // fall back
                        return
                    }
                    
                    continuation.resume(returning: (samplesOrNil ?? [], newAnchor))
                }
                
                healthStore.execute(query)
            }
            
            if let newAnchor = newAnchor {
                await HKAnchorStore.shared.saveAnchor(newAnchor, for: sampleType)
                currentAnchor = newAnchor
            }
            
            if samples.isEmpty {
                shouldContinue = false
            } else {
                await convertAndProcessSamples(samples)
            }
        }
    }
    
    private func convertAndProcessSamples(_ samples: [HKSample]) async {
        print("Processing samples...")
    }
}
