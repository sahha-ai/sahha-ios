import Testing
import Foundation
@testable import Sahha

/// Focused coverage of the CircuitBreaker state machine: closed → open → half-open
/// transitions, the success/failure accounting that drives them, and the
/// network-aware behavior that ignores connectivity failures.
@Suite("CircuitBreaker")
struct CircuitBreakerTests {

    @Test("Starts closed and allows requests")
    func startsClosed() async {
        let breaker = CircuitBreaker()
        #expect(await breaker.shouldAllowRequest() == true)
        #expect(await breaker.isHealthy() == true)
        #expect(await breaker.isOpen() == false)
        let (state, failures) = await breaker.getState()
        #expect(state == .closed)
        #expect(failures == 0)
    }

    @Test("Stays closed below the failure threshold")
    func staysClosedBelowThreshold() async {
        let breaker = CircuitBreaker(failureThreshold: 3, recoveryTimeout: 10)
        await breaker.recordFailure()
        await breaker.recordFailure()  // 2 of 3
        #expect(await breaker.shouldAllowRequest() == true)
        let (state, failures) = await breaker.getState()
        #expect(state == .closed)
        #expect(failures == 2)
    }

    @Test("Opens once the failure threshold is reached and fails fast")
    func opensAtThreshold() async {
        let breaker = CircuitBreaker(failureThreshold: 3, recoveryTimeout: 10)
        for _ in 0..<3 { await breaker.recordFailure() }
        #expect(await breaker.shouldAllowRequest() == false)  // before timeout: fail fast
        #expect(await breaker.isOpen() == true)
        #expect(await breaker.isHealthy() == false)
        let (state, _) = await breaker.getState()
        #expect(state == .open)
    }

    @Test("A success in the closed state resets the failure count")
    func successResetsFailureCountWhenClosed() async {
        let breaker = CircuitBreaker(failureThreshold: 3, recoveryTimeout: 10)
        await breaker.recordFailure()
        await breaker.recordFailure()
        await breaker.recordSuccess()
        let (state, failures) = await breaker.getState()
        #expect(state == .closed)
        #expect(failures == 0)
    }

    @Test("Transitions to half-open after the recovery timeout elapses")
    func recoversToHalfOpenAfterTimeout() async throws {
        let breaker = CircuitBreaker(failureThreshold: 1, recoveryTimeout: 0.1)
        await breaker.recordFailure()  // -> open
        try await Task.sleep(nanoseconds: 200_000_000)  // past recovery timeout
        #expect(await breaker.shouldAllowRequest() == true)  // the request that lazily transitions
        let (state, _) = await breaker.getState()
        #expect(state == .halfOpen)
    }

    @Test("Closes after enough successes in half-open")
    func closesAfterSuccessesInHalfOpen() async throws {
        let breaker = CircuitBreaker(failureThreshold: 1, recoveryTimeout: 0.1, halfOpenSuccessThreshold: 2)
        await breaker.recordFailure()
        try await Task.sleep(nanoseconds: 200_000_000)
        _ = await breaker.shouldAllowRequest()  // -> half-open

        await breaker.recordSuccess()           // 1 of 2: still testing recovery
        let (midState, _) = await breaker.getState()
        #expect(midState == .halfOpen)

        await breaker.recordSuccess()           // 2 of 2: backend healthy -> closed
        let (state, failures) = await breaker.getState()
        #expect(state == .closed)
        #expect(failures == 0)
    }

    @Test("A failure during half-open reopens the circuit")
    func failureInHalfOpenReopens() async throws {
        let breaker = CircuitBreaker(failureThreshold: 1, recoveryTimeout: 0.1, halfOpenSuccessThreshold: 2)
        await breaker.recordFailure()
        try await Task.sleep(nanoseconds: 200_000_000)
        _ = await breaker.shouldAllowRequest()  // -> half-open
        await breaker.recordFailure()           // recovery test fails -> reopen
        let (state, _) = await breaker.getState()
        #expect(state == .open)
    }

    @Test("reset() returns an open circuit to closed")
    func resetReturnsToClosed() async {
        let breaker = CircuitBreaker(failureThreshold: 1, recoveryTimeout: 10)
        await breaker.recordFailure()  // -> open
        #expect(await breaker.isOpen() == true)

        await breaker.reset()
        #expect(await breaker.shouldAllowRequest() == true)
        let (state, failures) = await breaker.getState()
        #expect(state == .closed)
        #expect(failures == 0)
    }

    @Test("Failures while the device is offline do not count toward the threshold")
    func offlineFailuresDoNotTripBreaker() async {
        let breaker = CircuitBreaker(failureThreshold: 1, recoveryTimeout: 10)
        let offlineMonitor = NetworkMonitor(isConnected: false)
        await breaker.setNetworkMonitor(offlineMonitor)

        // Threshold is 1, but an offline failure isn't the backend's fault, so it
        // must not open the circuit.
        await breaker.recordFailure()

        #expect(await breaker.shouldAllowRequest() == true)
        let (state, failures) = await breaker.getState()
        #expect(state == .closed)
        #expect(failures == 0)

        // CircuitBreaker holds the monitor weakly; this final use keeps it alive
        // through recordFailure() so the offline check above sees a live reference.
        #expect(await offlineMonitor.isConnected == false)
    }
}
