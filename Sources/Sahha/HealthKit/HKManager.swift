import HealthKit

final actor HKManager {
    static let shared = HKManager()
    
    private init() {}
    
    private let healthStore = HKHealthStore()
    
    private var activeSensors: Set<HKSampleType> = []
    private var isSensorStartInProgress = false
    
    func startSensors() {
        Task.detached(priority: .utility) {
            await self._startSensors()
        }
    }
    
    func reset() async {
        Task {
            for sampleType in activeSensors {
                await disableBackgroundDelivery(for: sampleType)
            }
            await HKQueryManager.shared.stopAllQueries()
            await HKAnchorStore.shared.clearAllAnchors()
            activeSensors.removeAll()
            SahhaLogger.info("All sensors stopped and background delivery disabled.")
        }
    }
    
    private func _startSensors(maxConcurrentTasks: Int = 4) async {
        guard !isSensorStartInProgress else { return }
        
        isSensorStartInProgress = true
        defer { isSensorStartInProgress = false }
        
        let enabled = await SensorStore.shared.getEnabledSensors()
        let enabledTypes = Set(enabled.compactMap(\.hkSampleType))
        let currentlyActive = self.activeSensors
        
        for sampleType in currentlyActive where !enabledTypes.contains(sampleType) {
            await HKQueryManager.shared.stopObserverQuery(for: sampleType)
            await HKQueryManager.shared.stopAnchorQuery(for: sampleType)
            await disableBackgroundDelivery(for: sampleType)
            activeSensors.remove(sampleType)
        }
        
        let semaphore = AsyncSemaphore(value: maxConcurrentTasks)
        
        await withTaskGroup(of: Void.self) { group in
            for sampleType in enabledTypes {
                group.addTask {
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }
                    await self.startSensor(sampleType)
                }
            }
        }
    }
    
    private func startSensor(_ sampleType: HKSampleType) async {
        guard !self.activeSensors.contains(sampleType) else { return }
        
        self.activeSensors.insert(sampleType)
        await HKQueryManager.shared.startObserverQuery(for: sampleType)
        await self.enableBackgroundDelivery(for: sampleType)
    }
    
    private func enableBackgroundDelivery(for sampleType: HKSampleType) async {
        do {
            try await healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate)
        } catch {
            SahhaLogger.error("Failed to enable background delivery for \(sampleType.identifier)")
        }
    }
    
    private func disableBackgroundDelivery(for sampleType: HKSampleType) async {
        do {
            try await healthStore.disableBackgroundDelivery(for: sampleType)
        } catch {
            SahhaLogger.error("Failed to disable background delivery for \(sampleType.identifier)")
        }
    }
}
