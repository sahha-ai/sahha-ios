import Testing
import Foundation
@testable import Sahha

/// Regression coverage for deauthentication resetting upload state.
///
/// On `Sahha.deauthenticate()` the DI container is reset: it disposes the
/// `UnifiedUploader` (which clears the chunk queue + dead-letter queue) and the
/// HealthKit anchor stores (which wipes the per-sensor query anchors). The next
/// session therefore re-queries history from scratch. For that re-queried history
/// to actually re-upload, the sent-ID dedup store must ALSO be cleared — otherwise
/// the re-queried items carry identical UUID5 ids, get filtered as "already sent",
/// and silently never upload. The visible symptom of the regression was that only
/// brand-new samples (e.g. a fresh night of sleep written overnight) re-uploaded
/// after a deauth/reauth, while all previously-synced history stayed on device.
@Suite("Deauthentication state reset")
struct DeauthStateResetTests {

    private func makeUploader(
        tempDir: URL,
        sentStore: SentItemStore
    ) -> UnifiedUploader<DataLog, DataLogRequest> {
        UnifiedUploader<DataLog, DataLogRequest>(
            uploadService: { _ in },
            logger: NoopErrorLogger(),
            circuitBreaker: CircuitBreaker(),
            networkMonitor: NetworkMonitor(isConnected: true),
            persistentQueue: UnifiedDeadLetterQueue<DataLogRequest>(baseDirectory: tempDir),
            streamingProcessor: StreamingChunkProcessor<DataLog, DataLogRequest>(
                // Unused: this test drives dispose() directly, not the item→request path.
                mapItem: { _ in
                    DataLogRequest(
                        id: "unused", logType: "activity", dataType: "steps",
                        value: 1, unit: "count", source: "test",
                        recordingMethod: "automatic", deviceType: "iPhone",
                        startDateTime: "2024-01-01T00:00:00.000",
                        endDateTime: "2024-01-01T00:00:00.000",
                        deviceId: "test-device"
                    )
                },
                assignPriority: { _ in .normal }
            ),
            sentStore: sentStore,
            logLabel: "DeauthStateResetTest"
        )
    }

    @Test("UnifiedUploader.dispose() clears the sent-ID dedup store so reauth re-uploads")
    func disposeClearsSentStore() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sentStore = SentItemStore(
            storage: InMemoryStorage(),
            storageKey: "test.sent.\(UUID().uuidString)"
        )

        // Simulate a previous session having uploaded sleep, steps and heart-rate logs.
        await sentStore.markSent(["sleep-1", "steps-1", "hr-1"])
        #expect(await sentStore.count() == 3)
        #expect(await sentStore.isSent("steps-1"))

        // Deauthentication path: the container disposes the uploader.
        let uploader = makeUploader(tempDir: tempDir, sentStore: sentStore)
        await uploader.dispose()

        // Dedup state must be gone — re-queried items are no longer "already sent".
        #expect(await sentStore.count() == 0)
        #expect(!(await sentStore.isSent("steps-1")))
        #expect(!(await sentStore.isSent("sleep-1")))
        #expect(!(await sentStore.isSent("hr-1")))
    }
}
