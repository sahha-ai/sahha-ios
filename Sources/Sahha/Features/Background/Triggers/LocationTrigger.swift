@preconcurrency import CoreLocation
import UIKit

@MainActor
final class LocationTrigger: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private weak var delegate: BackgroundTriggerDelegate?
    private var lastTriggerTime: Date?
    private let throttleInterval: TimeInterval = 20 * 60 // 20 minutes
    
    init(delegate: BackgroundTriggerDelegate) {
        self.delegate = delegate
        super.init()
        configureLocationManager()
    }
    
    private func configureLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        locationManager.distanceFilter = 3000 // 3km
        
        // Only enable background updates if the host app has the capability
        if let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String],
           backgroundModes.contains("location") {
            locationManager.allowsBackgroundLocationUpdates = true
        }
        
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.activityType = .other // Prevents auto-pause for fitness
    }
    
    func start() {
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestAlwaysAuthorization()
        }
        
        locationManager.startMonitoringSignificantLocationChanges()
        locationManager.startUpdatingLocation()
    }
    
    func stop() {
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let _ = locations.last else { return }
        
        Task { @MainActor in
            await handleTrigger()
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[Sahha] Location trigger error: \(error.localizedDescription)")
    }
    
    private func handleTrigger() async {
        let now = Date()
        if let lastTime = lastTriggerTime {
            if now.timeIntervalSince(lastTime) < throttleInterval {
                return
            }
        }
        
        lastTriggerTime = now
        await delegate?.triggerDidFire(source: "Location", fallbackData: nil)
    }
}
