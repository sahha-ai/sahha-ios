import Foundation

/// Circuit breaker state to prevent cascade failures
enum CircuitState {
    case closed      // Normal operation, requests go through
    case open        // Too many failures, fail fast to protect backend
    case halfOpen    // Testing if backend has recovered
}

/// Circuit breaker to prevent overwhelming a struggling backend
actor CircuitBreaker {
    private var state: CircuitState = .closed
    private var failureCount: Int = 0
    private var successCount: Int = 0
    private var lastFailureTime: Date?
    private weak var networkMonitor: NetworkMonitor?
    
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
    func setNetworkMonitor(_ monitor: NetworkMonitor) {
        self.networkMonitor = monitor
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
    
    /// Get current state for debugging
    func getState() async -> (state: CircuitState, failures: Int) {
        return (state, failureCount)
    }
    
    /// Reset circuit breaker (for testing or manual recovery)
    func reset() async {
        state = .closed
        failureCount = 0
        successCount = 0
        lastFailureTime = nil
        print("[Circuit Breaker] Manual reset to closed state")
    }
}

