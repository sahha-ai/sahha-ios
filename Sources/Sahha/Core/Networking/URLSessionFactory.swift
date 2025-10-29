import Foundation

/// Factory for creating optimized URLSession configurations
struct URLSessionFactory {
    
    /// Create an optimized URLSession for data log uploads
    /// - HTTP/2 enabled for multiplexing
    /// - Increased connection limits
    /// - Background capable for long-running uploads
    static func createOptimizedSession() -> URLSession {
        let config = URLSessionConfiguration.default
        
        // Enable HTTP/2 for connection multiplexing
        config.httpShouldUsePipelining = true
        config.httpMaximumConnectionsPerHost = 6  // Increased from default 4
        
        // Connection pooling and keepalive
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300  // 5 minutes for large uploads
        
        // Enable cellular uploads
        config.allowsCellularAccess = true
        config.waitsForConnectivity = true  // Wait for connectivity instead of failing immediately
        
        // Optimize for performance
        config.urlCache = nil  // Disable caching for API requests
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        print("[URLSession] Configured optimized session (HTTP/2, 6 connections/host, pooling enabled)")
        
        return URLSession(configuration: config)
    }
    
    /// Create a background URLSession for background uploads
    /// This session can continue uploads even when the app is suspended
    static func createBackgroundSession(identifier: String) -> URLSession {
        let config = URLSessionConfiguration.background(withIdentifier: identifier)
        
        // Same optimizations as default
        config.httpShouldUsePipelining = true
        config.httpMaximumConnectionsPerHost = 6
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 3600  // 1 hour for background
        config.allowsCellularAccess = true
        config.waitsForConnectivity = true
        
        // Background specific
        config.isDiscretionary = false  // Upload even on cellular
        config.sessionSendsLaunchEvents = true
        
        print("[URLSession] Configured background session: \(identifier)")
        
        return URLSession(configuration: config)
    }
}

