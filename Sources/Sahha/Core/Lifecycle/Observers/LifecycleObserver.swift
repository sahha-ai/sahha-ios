import Foundation
import UIKit

extension LifecycleEvent {
    fileprivate var notificationName: NSNotification.Name {
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

private class HandlerWrapper {
    weak var handler: LifecycleHandler?
    init(_ handler: LifecycleHandler) {
        self.handler = handler
    }
}

final actor LifecycleObserver: LifecycleObserverProtocol {
    private let notificationCenter = NotificationCenter.default
    private var observers: [LifecycleEvent: NSObjectProtocol] = [:]
    private var handlers: [(wrapper: HandlerWrapper, events: Set<LifecycleEvent>)] = []
    private var registeredEvents: Set<LifecycleEvent> = []
    private var lastNotificationTimes: [LifecycleEvent: Date] = [:]
    private let debounceInterval: TimeInterval = 0.5

    func addHandler(_ handler: LifecycleHandler, for events: Set<LifecycleEvent>) {
        let wrapper = HandlerWrapper(handler)
        handlers.append((wrapper: wrapper, events: events))
        handlers = handlers.filter { $0.wrapper.handler != nil }
        updateObservers()
    }

    func removeHandler(_ handler: LifecycleHandler) {
        handlers.removeAll { $0.wrapper.handler === handler }
        updateObservers()
    }

    private func updateObservers() {
        let allEvents = Set(handlers.flatMap { $0.events })

        for event in allEvents where !registeredEvents.contains(event) {
            let observer = notificationCenter.addObserver(forName: event.notificationName, object: nil, queue: .main) { [weak self] _ in
                guard let self = self else { return }
                Task { await self.notifyHandlers(event: event) }
            }
            observers[event] = observer
            registeredEvents.insert(event)
        }

        for event in registeredEvents where !allEvents.contains(event) {
            if let observer = observers[event] {
                notificationCenter.removeObserver(observer)
                observers.removeValue(forKey: event)
                registeredEvents.remove(event)
                lastNotificationTimes.removeValue(forKey: event)
            }
        }
    }

    private func notifyHandlers(event: LifecycleEvent) async {
        let currentTime = Date()
        if let lastTime = lastNotificationTimes[event],
            currentTime.timeIntervalSince(lastTime) < debounceInterval
        {
            print("LifeCycleObserver: Debounced event: \(event)")
            return
        }

        lastNotificationTimes[event] = currentTime
        print("LifeCycleObserver: Notifying handlers for event: \(event)")
        for (wrapper, events) in handlers where wrapper.handler != nil && events.contains(event) {
            await wrapper.handler!.handleLifecycleEvent(event: event)
        }
        handlers = handlers.filter { $0.wrapper.handler != nil }
    }
}
