import Foundation
import UIKit

protocol BackgroundCoordinatorProtocol: Sendable, Disposable {
    func start() async
    func stop() async
}

actor BackgroundCoordinator: BackgroundCoordinatorProtocol, BackgroundTriggerDelegate {
    private let healthKitManager: HealthKitManagerProtocol
    private let dataLogPipeline: DataLogPipelineProtocol
    private var locationTrigger: LocationTrigger?
    private var motionTrigger: MotionTrigger?
    private let logger: ErrorLoggerProtocol
    
    init(
        healthKitManager: HealthKitManagerProtocol,
        dataLogPipeline: DataLogPipelineProtocol,
        logger: ErrorLoggerProtocol
    ) {
        self.healthKitManager = healthKitManager
        self.dataLogPipeline = dataLogPipeline
        self.logger = logger
    }
    
    func start() async {
        await startLocationTrigger()
        await startMotionTrigger()
        
        print("[Sahha] Background Coordinator started")
    }

    func stop() async {
        await stopLocationTrigger()
        await stopMotionTrigger()
        print("[Sahha] Background Coordinator stopped")
    }
    
    func dispose() async {
        await stop()
    }
    
    func triggerDidFire(source: String, fallbackData: [DataLog]?) async {
        print("[Sahha] Background trigger fired: \(source)")
        
        // Check for protected data availability
        let isProtected = await MainActor.run {
            !UIApplication.shared.isProtectedDataAvailable
        }
        
        if isProtected {
            print("[Sahha] Device is locked. Attempting fetch anyway.")
        }
        
        let result = await healthKitManager.querySensors()
        
        // Fallback Logic
        if isProtected, result.totalLogs == 0, let fallbackData, !fallbackData.isEmpty {
             print("[Sahha] Using fallback Motion data (\(fallbackData.count) logs) as HK failed/empty.")
             await dataLogPipeline.ingest(fallbackData)
        }
    }

    private func startLocationTrigger() async {
        if locationTrigger == nil {
            let trigger = await MainActor.run { LocationTrigger(delegate: self) }
            locationTrigger = trigger
        }
        guard let trigger = locationTrigger else { return }
        await MainActor.run {
            trigger.start()
        }
    }

    private func stopLocationTrigger() async {
        guard let trigger = locationTrigger else { return }
        await MainActor.run {
            trigger.stop()
        }
    }

    private func startMotionTrigger() async {
        if motionTrigger == nil {
            motionTrigger = MotionTrigger(delegate: self)
        }
        await motionTrigger?.start()
    }

    private func stopMotionTrigger() async {
        await motionTrigger?.stop()
    }
}
