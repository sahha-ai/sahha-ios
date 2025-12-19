import Foundation

/// Delegate to handle background URLSession task completion events
/// This allows uploads to continue even when the app is suspended
/// Note: Marked @unchecked Sendable because synchronization is handled via DispatchQueue
final class BackgroundSessionDelegate: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate, @unchecked Sendable {
    private let circuitBreaker: CircuitBreaker?
    private let logger: ErrorLoggerProtocol?
    
    // Store completion handlers for background session events
    private var completionHandlers: [String: @Sendable () -> Void] = [:]
    private let queue = DispatchQueue(label: "ai.sahha.background.delegate")
    
    init(circuitBreaker: CircuitBreaker?, logger: ErrorLoggerProtocol?) {
        self.circuitBreaker = circuitBreaker
        self.logger = logger
    }
    
    // MARK: - Background Session Completion Handler
    
    /// Store completion handler for background session events
    /// This should be called from AppDelegate's handleEventsForBackgroundURLSession
    func setCompletionHandler(_ handler: @escaping @Sendable () -> Void, for identifier: String) {
        queue.async { [weak self] in
            self?.completionHandlers[identifier] = handler
        }
    }
    
    /// Call the stored completion handler when all background tasks are done
    private func callCompletionHandler(for identifier: String) {
        queue.async { [weak self] in
            guard let self = self,
                  let handler = self.completionHandlers[identifier] else { return }
            
            DispatchQueue.main.async {
                handler()
            }
            
            self.completionHandlers.removeValue(forKey: identifier)
        }
    }
    
    // MARK: - URLSessionTaskDelegate
    
    /// Called when a background task completes (success or failure)
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Task { [weak self] in
            guard let self else { return }
            
            if let error = error {
                // Task failed
                print("[Background Upload] Task failed: \(error.localizedDescription)")
                await self.circuitBreaker?.recordFailure()
                await self.logger?.postError(error)
            } else if let httpResponse = task.response as? HTTPURLResponse {
                // Task completed - check status code
                switch httpResponse.statusCode {
                case 200...299:
                    print("[Background Upload] Task succeeded with status \(httpResponse.statusCode)")
                    await self.circuitBreaker?.recordSuccess()
                default:
                    print("[Background Upload] Task failed with status \(httpResponse.statusCode)")
                    await self.circuitBreaker?.recordFailure()
                }
            }
            
            // Check if this was the last task in the session
            if let identifier = session.configuration.identifier {
                session.getAllTasks { tasks in
                    if tasks.isEmpty {
                        // All tasks completed - call completion handler
                        self.callCompletionHandler(for: identifier)
                    }
                }
            }
        }
    }
    
    // MARK: - URLSessionDataDelegate
    
    /// Collect response data for background tasks
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // Background tasks receive data in chunks
        // For now, we just log it since we don't need to decode responses for uploads
        print("[Background Upload] Received \(data.count) bytes")
    }
}

