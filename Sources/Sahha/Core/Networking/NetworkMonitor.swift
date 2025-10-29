import Foundation
import Network

/// Monitors network connectivity state
actor NetworkMonitor {
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "ai.sahha.networkmonitor")
    private var isMonitoring = false
    
    private(set) var isConnected: Bool = true
    private(set) var connectionType: NWInterface.InterfaceType?
    
    // Callbacks for network state changes
    private var stateChangeCallbacks: [(Bool) -> Void] = []
    
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
    func onStateChange(_ callback: @escaping (Bool) -> Void) {
        stateChangeCallbacks.append(callback)
    }
    
    /// Notify all registered callbacks
    private func notifyStateChange(_ connected: Bool) {
        for callback in stateChangeCallbacks {
            callback(connected)
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
}

enum NetworkError: Error {
    case timeout
    case notConnected
}

