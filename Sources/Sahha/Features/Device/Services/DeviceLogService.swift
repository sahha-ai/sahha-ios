final actor DeviceLogService: LifecycleListener {
    private let collector: DeviceInfoCollecting
    private let sensorStore: SensorStoring
    private let pipeline: DataLogPipelineProviding
    private let logger: ErrorLogger
    
    init(
        collector: DeviceInfoCollecting,
        sensorStore: SensorStoring,
        pipeline: DataLogPipelineProviding,
        logger: ErrorLogger
    ) {
        self.collector = collector
        self.sensorStore = sensorStore
        self.pipeline = pipeline
        self.logger = logger
    }
    
    func handleLifecycleEvent(_ event: LifecycleEvent) async {
        if event == .app_locked || event == .app_unlocked {
            let enabled = await sensorStore.loadSensors()
            guard enabled.contains(.device_lock) else { return }
        }
    
        do {
            let deviceInfo = try await collector.collect()
            let deviceLog = event.toDataLog(deviceInfo: deviceInfo)
            try await pipeline.ingest([deviceLog])
        } catch {
            logger.sdkError("Failed to ingest device log",error: error)
        }
    }
}
