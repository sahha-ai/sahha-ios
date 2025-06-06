import HealthKit

final actor HKManager {
    static let shared = HKManager()
    
    private init() {}
    
    private let healthStore = HKHealthStore()
    private var activeSensors: Set<HKObjectType> = []
    private let queryManager = HKQueryManager.shared
    private var isSensorStartInProgress = false
    
    func startSensors() {
        Task.detached(priority: .utility) {
            await self._startSensors()
        }
    }
    
    private func _startSensors(maxConcurrentTasks: Int = 4) async {
        guard !isSensorStartInProgress else { return }
        
        isSensorStartInProgress = true
        defer { isSensorStartInProgress = false }
        
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
        await queryManager.startObserverQuery(for: sampleType)
        await self.enableBackgroundDelivery(for: sampleType)
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
}
