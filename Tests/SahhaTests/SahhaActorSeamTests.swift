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

    @Test("Configure-time bring-up failures reach the injected error logger")
    func bringUpErrorsReachInjectedLogger() async throws {
        let recorder = RecordingErrorLogger()

        let actor = SahhaActor(
            registrar: { container, settings in
                await SahhaActor.registerProductionDependencies(container: container, settings: settings)
                await container.register(UserDefaultsStorageProtocol.self) { _ in InMemoryStorage() }
                await container.register(KeychainStorageProtocol.self) { _ in MockKeychainStorage() }
                await container.register(ErrorLoggerProtocol.self) { _ in recorder }
                // A signed-in session, so configure runs authenticated bring-up.
                await container.register(AuthManagerProtocol.self) { _ in
                    MockAuthManager(validToken: "token", refreshedToken: "token")
                }
                // Every bring-up dependency fails to build. Each branch catches and
                // logs — which only reaches the injected logger if the actor's
                // container is assigned BEFORE bring-up runs (the D5 hoist). With
                // the old order, this test records zero errors.
                await container.register(HealthKitManagerProtocol.self) { _ in
                    throw SahhaError(message: "bring-up fixture: health kit manager unavailable")
                }
                await container.register(DeviceInfoSyncManagerProtocol.self) { _ in
                    throw SahhaError(message: "bring-up fixture: device info sync unavailable")
                }
                await container.register(DemographicManagerProtocol.self) { _ in
                    throw SahhaError(message: "bring-up fixture: demographic manager unavailable")
                }
                await container.register(BackgroundCoordinatorProtocol.self) { _ in
                    throw SahhaError(message: "bring-up fixture: background coordinator unavailable")
                }
            },
            lifecycleObserver: LifecycleObserverSpy()
        )

        try await actor.configure(with: SahhaSettings(environment: .sandbox))

        let messages = recorder.drain().compactMap { ($0.error as? SahhaError)?.message }
        #expect(messages.contains("bring-up fixture: health kit manager unavailable"))
    }

    @Test("The circuit breaker stays unregistered in the production graph")
    func circuitBreakerRemainsUnregistered() async throws {
        // PRD #76 D5 explicitly leaves the breaker dead: registering it would switch
        // on error-drop behavior nobody has decided on. LoggingDI resolves it with
        // `try?`, so the logger builds fine while this resolve keeps failing.
        let container = DIContainer()
        await SahhaActor.registerProductionDependencies(
            container: container,
            settings: SahhaSettings(environment: .sandbox)
        )
        await #expect(throws: (any Error).self) {
            _ = try await container.resolve(CircuitBreaker.self)
        }
    }
}
