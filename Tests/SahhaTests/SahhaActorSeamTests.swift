import Testing
import Foundation
@testable import Sahha

/// The `SahhaActor` test seam (PRD #76, D2a): integration suites construct a
/// non-shared actor whose registration list swaps real persistence for doubles.
///
/// Note for suite authors: tests that must drive the SHARED actor
/// (`SahhaActor.shared` or the `Sahha` facade) belong in a `.serialized` suite —
/// swift-testing runs tests in parallel by default, and concurrent tests mutating
/// the developer's real UserDefaults/Keychain through one shared actor race each
/// other. Non-shared actors over doubles (like here) stay parallel-safe.
@Suite("SahhaActor seam")
struct SahhaActorSeamTests {

    @Test("A non-shared actor configures through an injected registration list")
    func injectedRegistrarIsUsed() async throws {
        let storage = InMemoryStorage()
        let keychain = MockKeychainStorage()
        let observerSpy = LifecycleObserverSpy()

        let actor = SahhaActor(
            registrar: { container, settings in
                // The production graph with the persistence seams swapped for doubles.
                await SahhaActor.registerProductionDependencies(container: container, settings: settings)
                await container.register(UserDefaultsStorageProtocol.self) { _ in storage }
                await container.register(KeychainStorageProtocol.self) { _ in keychain }
            },
            lifecycleObserver: observerSpy
        )

        try await actor.configure(with: SahhaSettings(environment: .sandbox))

        // Configuration completed against the injected graph…
        _ = try await actor.requireConfig()
        // …and its storage side effects landed in the double, not UserDefaults.standard:
        // configure writes the DLQ migration marker through the resolved storage.
        #expect(storage.get(forKey: "dlq_migration_v1_complete") as? Bool == true)
        // The device-log listener was registered on the injected observer.
        #expect(await observerSpy.registrationCount == 1)
    }
}
