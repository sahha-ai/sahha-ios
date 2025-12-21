import Foundation
import Network

/// Monitors network connectivity state
actor NetworkMonitor: Disposable {
    typealias CallbackToken = UUID
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "ai.sahha.networkmonitor")
    private var isMonitoring = false
    
    private(set) var isConnected: Bool = true
    private(set) var connectionType: NWInterface.InterfaceType?
    
    // Callbacks for network state changes (keyed by token for removal)
    private var stateChangeCallbacks: [CallbackToken: @Sendable (Bool) async -> Void] = [:]
    
    init() {
        self.monitor = NWPathMonitor()
    }
    
    /// Start monitoring network state
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        monitor.pathUpdateHandler = { [weak self] path in
            Task { [weak self] in
                await self?.handlePathUpdate(path)
            }
        }
        
        monitor.start(queue: queue)
        isMonitoring = true
        print("[Network Monitor] Started monitoring network connectivity")
    }
    
    /// Stop monitoring network state
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        monitor.cancel()
        isMonitoring = false
        print("[Network Monitor] Stopped monitoring network connectivity")
    }
    
    /// Handle path updates from NWPathMonitor
    private func handlePathUpdate(_ path: NWPath) {
        let wasConnected = isConnected
        isConnected = path.status == .satisfied
        
        // Determine connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .wiredEthernet
        } else {
            connectionType = nil
        }
        
        // Log state changes
        if wasConnected != isConnected {
            if isConnected {
                let typeString = connectionType.map { "\($0)" } ?? "unknown"
                print("[Network Monitor] Connected via \(typeString)")
            } else {
                print("[Network Monitor] Disconnected")
            }
            
            // Notify callbacks
            notifyStateChange(isConnected)
        }
    }
    
    /// Register callback for network state changes
    /// - Parameter callback: Async closure called when network state changes
    /// - Returns: Token that can be used to remove the callback later
    func onStateChange(_ callback: @escaping @Sendable (Bool) async -> Void) async -> CallbackToken {
        let token = UUID()
        stateChangeCallbacks[token] = callback
        return token
    }
    
    /// Remove a previously registered callback
    /// - Parameter token: The token returned from onStateChange
    func removeCallback(token: CallbackToken) async {
        stateChangeCallbacks.removeValue(forKey: token)
    }
    
    /// Notify all registered callbacks
    private nonisolated func notifyStateChange(_ connected: Bool) {
        Task {
            let callbacks = await stateChangeCallbacks.values
            for callback in callbacks {
                await callback(connected)
            }
        }
    }
    
    /// Wait for network to become available
    func waitForConnectivity(timeout: TimeInterval = 30) async throws {
        guard !isConnected else { return }
        
        print("[Network Monitor] Waiting for connectivity...")
        
        let startTime = Date()
        while !isConnected {
            if Date().timeIntervalSince(startTime) > timeout {
                throw NetworkError.timeout
            }
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        print("[Network Monitor] Connectivity restored")
    }
    
    /// Check if we should attempt upload based on connection type
    func shouldAttemptUpload() -> Bool {
        guard isConnected else { return false }
        
        // Could add logic here to prefer WiFi for large uploads
        // For now, allow uploads on any connection
        return true
    }
    
    /// Dispose of network monitor resources
    func dispose() async {
        stopMonitoring()
        stateChangeCallbacks.removeAll()
        print("[Network Monitor] Disposed and cleaned up all callbacks")
    }
}

enum NetworkError: Error {
    case timeout
    case notConnected
}

