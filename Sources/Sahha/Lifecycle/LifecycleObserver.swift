import Foundation
import UIKit

@MainActor
final class LifecycleObserver {
    static let shared = LifecycleObserver()
    
    private init() {}
    
    private var hasEmittedAppOpen = false
    private var observersAdded = false
    
    private let lifecycleBindings: [(Selector, NSNotification.Name)] = [
        (#selector(handleAppStart), UIApplication.didFinishLaunchingNotification),
        (#selector(handleAppOpen), UIApplication.didBecomeActiveNotification),
        (#selector(handleAppPause), UIApplication.willResignActiveNotification),
        (#selector(handleAppForeground), UIApplication.willEnterForegroundNotification),
        (#selector(handleAppBackground), UIApplication.didEnterBackgroundNotification),
        (#selector(handleAppClose), UIApplication.willResignActiveNotification),
        (#selector(handleAppDestroy), UIApplication.willTerminateNotification),
        (#selector(handleDeviceUnlock), UIApplication.protectedDataDidBecomeAvailableNotification),
        (#selector(handleDeviceLock), UIApplication.protectedDataWillBecomeUnavailableNotification),
    ]
    
    func start() {
        guard !observersAdded else { return }
        
        lifecycleBindings.forEach {
            NotificationCenter.default.addObserver(self, selector:$0.0, name: $0.1, object: nil)
        }
        
        observersAdded = true
    }
    
    func stop() {
        guard observersAdded else { return }
        
        lifecycleBindings.forEach {
            NotificationCenter.default.removeObserver(self, name: $0.1, object: nil)
        }
        
        observersAdded = false
    }
    
    @objc private func handleAppStart() {
        logLifecycleEvent(.appStart)
    }

    @objc private func handleAppOpen() {
        if hasEmittedAppOpen {
            logLifecycleEvent(.appResume)
        } else {
            hasEmittedAppOpen = true
            logLifecycleEvent(.appOpen)
            
            Task {
                if let token = await TokenStore.shared.getProfileToken() {
                    await DeviceInformationManager.shared.sync()
                }
            }
        }
    }

    @objc private func handleAppPause() {
        logLifecycleEvent(.appPause)
    }

    @objc private func handleAppForeground() {
        logLifecycleEvent(.appForeground)
    }

    @objc private func handleAppBackground() {
        logLifecycleEvent(.appBackground)
    }

    @objc private func handleAppClose() {
        logLifecycleEvent(.appClose)
    }

    @objc private func handleAppDestroy() {
        logLifecycleEvent(.appDestroy)
    }

    @objc private func handleDeviceUnlock() {
        logLifecycleEvent(.deviceUnlock)
    }

    @objc private func handleDeviceLock() {
        logLifecycleEvent(.deviceLock)
    }
    
    private func logLifecycleEvent(_ event: LifecycleEvent) {
        Task {
            await LifecycleEventManager.shared.track(event)
        }
    }
    
}
