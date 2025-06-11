import Foundation

actor LifecycleEventManager {
    static let shared = LifecycleEventManager()
    
    private init() {}
    
    private var lastEventTimestamps: [LifecycleEvent: Date] = [:]
    private let debounceInterval: TimeInterval = 3.0
    
    func track(_ event: LifecycleEvent) {
        Task {
            let allowed = await isTrackingAllowed(for: event)
            let shouldTrack = await shouldTrackEvent(event)
            
            guard allowed && shouldTrack else { return }
            
            lastEventTimestamps[event] = Date()
            
            // TODO: Map LifecycleEvent -> DataLog then add to DataLogQueue
        }
    }
    
    private func isTrackingAllowed(for event: LifecycleEvent) async -> Bool {
        switch event {
        case .deviceLock, .deviceUnlock:
            return await SensorStore.shared.isEnabled(.device_lock)
        default:
            return true
        }
    }
    
    private func shouldTrackEvent(_ event: LifecycleEvent) async -> Bool {
        guard await TokenStore.shared.getProfileToken() != nil else {
            return false
        }
        
        let now = Date()
        guard let last = lastEventTimestamps[event] else {
            return true
        }
        return now.timeIntervalSince(last) >= debounceInterval
    }
}
