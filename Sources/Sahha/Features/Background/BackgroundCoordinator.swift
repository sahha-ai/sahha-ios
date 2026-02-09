import Foundation
import UIKit

protocol BackgroundCoordinatorProtocol: Sendable, Disposable {
    func start() async
    func stop() async
}

actor BackgroundCoordinator: BackgroundCoordinatorProtocol, BackgroundTriggerDelegate {
    private let healthKitManager: HealthKitManagerProtocol
    private let dataLogPipeline: DataLogPipelineProtocol
    private var motionTrigger: MotionTrigger?
    private let logger: ErrorLoggerProtocol
    private let enableMotionTrigger: Bool
    
    init(
        healthKitManager: HealthKitManagerProtocol,
        dataLogPipeline: DataLogPipelineProtocol,
        logger: ErrorLoggerProtocol,
        enableMotionTrigger: Bool = false
    ) {
        self.healthKitManager = healthKitManager
        self.dataLogPipeline = dataLogPipeline
        self.logger = logger
        self.enableMotionTrigger = enableMotionTrigger
    }
    
    func start() async {
        if enableMotionTrigger {
            await startMotionTrigger()
        } else {
            Sahha.log("[Sahha] Motion trigger disabled by configuration")
        }
        
        Sahha.log("[Sahha] Background Coordinator started")
    }

    func stop() async {
        if enableMotionTrigger {
            await stopMotionTrigger()
        }
        Sahha.log("[Sahha] Background Coordinator stopped")
    }
    
    func dispose() async {
        await stop()
    }
    
    func triggerDidFire(source: String, fallbackData: [DataLog]?) async {
        Sahha.log("[Sahha] Background trigger fired: \(source)")
        
        // Check for protected data availability
        let isProtected = await MainActor.run {
            !UIApplication.shared.isProtectedDataAvailable
        }
        
        if isProtected {
            Sahha.log("[Sahha] Device is locked. Attempting fetch anyway.")
        }
        
        let result = await healthKitManager.querySensors()
        
        // Fallback Logic - only if HealthKit yields NO logs
        if isProtected, result.totalLogs == 0, let fallbackData, !fallbackData.isEmpty {
             Sahha.log("[Sahha] Using fallback Motion data (\(fallbackData.count) logs) as HK failed/empty.")
             await dataLogPipeline.ingest(fallbackData)
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
