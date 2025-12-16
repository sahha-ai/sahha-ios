@preconcurrency import CoreMotion
import UIKit

actor MotionTrigger {
    private let pedometer = CMPedometer()
    private weak var delegate: BackgroundTriggerDelegate?
    private let interval: TimeInterval = 30 * 60 // 30 minutes
    
    private var isRunning = false
    private var lastTriggerTime: Date?
    private var timerTask: Task<Void, Never>?
    
    init(delegate: BackgroundTriggerDelegate) {
        self.delegate = delegate
    }
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        
        // Timer Loop - Store task reference for proper cleanup
        timerTask = Task { [weak self] in
            guard let self else { return }
            while await self.isRunning {
                try? await Task.sleep(nanoseconds: UInt64(30 * 60 * 1_000_000_000))
                guard await self.isRunning else { break }
                await self.checkActivityAndTrigger()
            }
        }
        
        // Pedometer Event Loop
        if CMPedometer.isPedometerEventTrackingAvailable() {
            pedometer.startEventUpdates { [weak self] event, error in
                guard let self = self, error == nil else { return }
                Task {
                    await self.checkActivityAndTrigger()
                }
            }
        }
    }
    
    func stop() {
        isRunning = false
        timerTask?.cancel()
        timerTask = nil
        pedometer.stopEventUpdates()
    }
    
    private func checkActivityAndTrigger() async {
        let now = Date()
        let last = lastTriggerTime ?? now.addingTimeInterval(-interval)
        
        // Check throttle BEFORE updating timestamp
        if let lastTime = lastTriggerTime {
            let timeSinceLastTrigger = now.timeIntervalSince(lastTime)
            if timeSinceLastTrigger < interval {
                return
            }
        }
        
        // Only update timestamp when query actually fires
        lastTriggerTime = now
        
        do {
            let data = try await queryPedometerData(from: last, to: now)
            let logs = convertToDataLogs(data)
            await delegate?.triggerDidFire(source: "Motion", fallbackData: logs)
        } catch {
            await delegate?.triggerDidFire(source: "Motion", fallbackData: nil)
        }
    }
    
    
    private func queryPedometerData(from start: Date, to end: Date) async throws -> CMPedometerData {
        return try await withCheckedThrowingContinuation { continuation in
            pedometer.queryPedometerData(from: start, to: end) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: NSError(domain: "Sahha", code: -1, userInfo: [NSLocalizedDescriptionKey: "No pedometer data"]))
                }
            }
        }
    }
    
    private func convertToDataLogs(_ data: CMPedometerData) -> [DataLog] {
        var logs: [DataLog] = []
        
        let steps = data.numberOfSteps.doubleValue
        if steps > 0 {
             let log = DataLog(
                logType: .activity,
                dataType: "steps",
                value: steps,
                unit: "count",
                source: "CoreMotion",
                recordingMethod: .automatic,
                deviceType: "iPhone",
                startDate: data.startDate,
                endDate: data.endDate
             )
             logs.append(log)
        }
        return logs
    }
}
