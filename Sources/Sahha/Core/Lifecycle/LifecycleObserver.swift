import Foundation
import UIKit

protocol LifecycleObserverProtocol: Actor, DisposableActor {
    func startObserving() async
    func stopObserving() async
}

actor LifecycleObserver: LifecycleObserverProtocol {
    private let deviceInfoService: DeviceInfoServiceProtocol
    
    private var observers: [NSObjectProtocol] = []
    private var hasEmittedAppOpen = false
    
    private enum LifecycleEvent: Sendable {
        case appStart
        case appDidBecomeActive
        case appPause
        case appForeground
        case appBackground
        case appClose
        case deviceUnlock
        case deviceLock
        
        var notificationName: NSNotification.Name {
            switch self {
            case .appStart: return UIApplication.didFinishLaunchingNotification
            case .appDidBecomeActive: return UIApplication.didBecomeActiveNotification
            case .appPause: return UIApplication.willResignActiveNotification
            case .appForeground: return UIApplication.willEnterForegroundNotification
            case .appBackground: return UIApplication.didEnterBackgroundNotification
            case .appClose: return UIApplication.willTerminateNotification
            case .deviceUnlock: return UIApplication.protectedDataDidBecomeAvailableNotification
            case .deviceLock: return UIApplication.protectedDataWillBecomeUnavailableNotification
            }
        }
    }
    
    init(deviceInfoService: DeviceInfoServiceProtocol) {
        self.deviceInfoService = deviceInfoService
    }
    
    func startObserving() async {
        let center = NotificationCenter.default
        let events: [LifecycleEvent] = [
            .appStart,
            .appDidBecomeActive,
            .appPause,
            .appForeground,
            .appBackground,
            .appClose,
            .deviceUnlock,
            .deviceLock
        ]
        
        for event in events {
            let observer = center.addObserver(
                forName: event.notificationName,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { await self?.handleEvent(event) }
            }
            observers.append(observer)
        }
        print("LifecycleObserver started observing app lifecycle events")
    }
    
    func stopObserving() async {
        let center = NotificationCenter.default
        for observer in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()
        hasEmittedAppOpen = false
        print("LifecycleObserver stopped observing app lifecycle events")
    }
    
    func dispose() async {
        await stopObserving()
    }
    
    private func handleEvent(_ event: LifecycleEvent) async {
        switch event {
        case .appStart:
            await handleAppStart()
        case .appDidBecomeActive:
            await handleAppDidBecomeActive()
        case .appPause:
            await handleAppPause()
        case .appForeground:
            await handleAppForeground()
        case .appBackground:
            await handleAppBackground()
        case .appClose:
            await handleAppClose()
        case .deviceUnlock:
            await handleDeviceUnlock()
        case .deviceLock:
            await handleDeviceLock()
        }
    }
    
    private func handleAppStart() async {
        print("Lifecycle event: appStart")
    }
    
    private func handleAppDidBecomeActive() async {
        let event = hasEmittedAppOpen ? "appResume" : "appOpen"
        print("Lifecycle event: \(event)")
        
        do {
            try await deviceInfoService.sync()
            print("Device info synced successfully on \(event)")
            hasEmittedAppOpen = true
        } catch {
            print("Failed to sync device info on \(event): \(error)")
        }
    }
    
    private func handleAppPause() async {
        print("Lifecycle event: appPause")
    }
    
    private func handleAppForeground() async {
        print("Lifecycle event: appForeground")
    }
    
    private func handleAppBackground() async {
        print("Lifecycle event: appBackground")
    }
    
    private func handleAppClose() async {
        print("Lifecycle event: appClose")
    }
    
    private func handleDeviceUnlock() async {
        print("Lifecycle event: deviceUnlock")
    }
    
    private func handleDeviceLock() async {
        print("Lifecycle event: deviceLock")
    }
}
