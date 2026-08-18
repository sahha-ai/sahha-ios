final class SensorProbeLifecycleListener: LifecycleListener, @unchecked Sendable {
    private let probeService: SensorProbeServiceProtocol

    init(probeService: SensorProbeServiceProtocol) {
        self.probeService = probeService
    }

    func handleLifecycleEvent(_ event: LifecycleEvent) async {
        await probeService.runProbe()
    }
}
