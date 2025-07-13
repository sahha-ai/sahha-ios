import Foundation
import UIKit

protocol LifecycleObserver: Actor, Disposable {
    func addHandler(_ handler: LifecycleHandler, for events: Set<LifecycleEvent>)
    func removeHandler(_ handler: LifecycleHandler)
}

private class HandlerWrapper {
    weak var handler: LifecycleHandler?
    init(_ handler: LifecycleHandler) {
        self.handler = handler
    }
}

final actor LifecycleObserverImpl: LifecycleObserver {
    private let logger: Logger
    private let notificationCenter = NotificationCenter.default
    private var observers: [LifecycleEvent: NSObjectProtocol] = [:]
    private var handlers: [(wrapper: HandlerWrapper, events: Set<LifecycleEvent>)] = []
    private var registeredEvents: Set<LifecycleEvent> = []
    private var lastNotificationTimes: [LifecycleEvent: Date] = [:]
    private let debounceInterval: TimeInterval = 0.5

    init(logger: Logger) {
        self.logger = logger
    }

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

    func dispose() async {
        handlers.removeAll()
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
            logger.info("LifeCycleObserver: Debounced event: \(event)")
            return
        }

        lastNotificationTimes[event] = currentTime
        logger.info("LifeCycleObserver: Notifying handlers for event: \(event)")
        for (wrapper, events) in handlers where wrapper.handler != nil && events.contains(event) {
            await wrapper.handler!.handleLifecycleEvent(event: event)
        }
        handlers = handlers.filter { $0.wrapper.handler != nil }
    }
}
