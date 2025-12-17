import Foundation

/// Circuit breaker state to prevent cascade failures
enum CircuitState {
    case closed      // Normal operation, requests go through
    case open        // Too many failures, fail fast to protect backend
    case halfOpen    // Testing if backend has recovered
}

/// Circuit breaker to prevent overwhelming a struggling backend
actor CircuitBreaker: Disposable {
    private var state: CircuitState = .closed
    private var failureCount: Int = 0
    private var successCount: Int = 0
    private var lastFailureTime: Date?
    private weak var networkMonitor: NetworkMonitor?
    private var networkCallbackToken: NetworkMonitor.CallbackToken?
    
    // Configuration
    private let failureThreshold: Int
    private let recoveryTimeout: TimeInterval
    private let halfOpenSuccessThreshold: Int
    
    init(
        failureThreshold: Int = 5,  
        recoveryTimeout: TimeInterval = 60,
        halfOpenSuccessThreshold: Int = 2
    ) {
        self.failureThreshold = failureThreshold
        self.recoveryTimeout = recoveryTimeout
        self.halfOpenSuccessThreshold = halfOpenSuccessThreshold
    }
    
    /// Inject network monitor for connectivity-aware circuit breaking
    /// Also registers callback to open circuit when device goes offline
    func setNetworkMonitor(_ monitor: NetworkMonitor) async {
        self.networkMonitor = monitor
        
        // Register callback to open circuit when network disconnects
        // Store token for cleanup
        let token = await monitor.onStateChange { [weak self] isConnected in
            guard let self else { return }
            
            if !isConnected {
                // Device went offline - open circuit immediately
                await self.handleNetworkDisconnected()
            } else {
                // Device came back online - allow recovery testing
                await self.handleNetworkReconnected()
            }
        }
        self.networkCallbackToken = token
    }
    
    /// Handle network disconnection - open circuit to prevent wasted attempts
    private func handleNetworkDisconnected() async {
        guard state != .open else { return }
        
        print("[Circuit Breaker] Network disconnected - opening circuit")
        state = .open
        lastFailureTime = Date()
    }
    
    /// Handle network reconnection - allow recovery testing
    private func handleNetworkReconnected() async {
        guard state == .open else { return }
        
        print("[Circuit Breaker] Network reconnected - transitioning to half-open for testing")
        state = .halfOpen
        successCount = 0
    }
    
    /// Check if request should be allowed
    func shouldAllowRequest() async -> Bool {
        switch state {
        case .closed:
            return true
            
        case .open:
            // Check if enough time has passed to try recovery
            if let lastFailure = lastFailureTime,
               Date().timeIntervalSince(lastFailure) >= recoveryTimeout {
                print("[Circuit Breaker] Transitioning to half-open, testing recovery...")
                state = .halfOpen
                successCount = 0
                return true
            }
            print("[Circuit Breaker] Circuit is OPEN, failing fast to protect backend")
            return false
            
        case .halfOpen:
            // Allow limited requests to test recovery
            return true
        }
    }
    
    /// Record a successful request
    func recordSuccess() async {
        switch state {
        case .closed:
            failureCount = 0
            
        case .halfOpen:
            successCount += 1
            if successCount >= halfOpenSuccessThreshold {
                print("[Circuit Breaker] Backend recovered, closing circuit")
                state = .closed
                failureCount = 0
                successCount = 0
                lastFailureTime = nil
            }
            
        case .open:
            break
        }
    }
    
    /// Record a failed request
    func recordFailure() async {
        lastFailureTime = Date()
        
        // Check if failure is due to network connectivity
        let isNetworkIssue = await networkMonitor?.isConnected == false
        
        if isNetworkIssue {
            print("[Circuit Breaker] Failure due to network disconnection, not counting towards threshold")
            // Don't count network failures towards circuit breaker threshold
            // The device being offline isn't the backend's fault
            return
        }
        
        switch state {
        case .closed:
            failureCount += 1
            if failureCount >= failureThreshold {
                print("[Circuit Breaker] Threshold reached (\(failureCount) failures), opening circuit for \(recoveryTimeout)s")
                state = .open
            }
            
        case .halfOpen:
            print("[Circuit Breaker] Recovery test failed, reopening circuit")
            state = .open
            successCount = 0
            
        case .open:
            break
        }
    }
    
    /// Get current state for debugging and decision making
    func getState() async -> (state: CircuitState, failures: Int) {
        return (state, failureCount)
    }
    
    /// Check if the circuit is healthy (closed state)
    func isHealthy() async -> Bool {
        return state == .closed
    }
    
    /// Check if the circuit is open (failing fast)
    func isOpen() async -> Bool {
        return state == .open
    }
    
    /// Reset circuit breaker (for testing or manual recovery)
    func reset() async {
        state = .closed
        failureCount = 0
        successCount = 0
        lastFailureTime = nil
        print("[Circuit Breaker] Manual reset to closed state")
    }
    
    /// Clean up network monitor callback registration
    func cleanup() async {
        if let token = networkCallbackToken, let monitor = networkMonitor {
            await monitor.removeCallback(token: token)
            networkCallbackToken = nil
        }
    }
    
    /// Dispose of circuit breaker resources
    func dispose() async {
        await cleanup()
        print("[Circuit Breaker] Disposed and cleaned up network monitor callback")
    }
}

