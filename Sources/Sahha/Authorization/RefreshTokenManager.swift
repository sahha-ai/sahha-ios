import Foundation

final actor RefreshTokenManager {
    static let shared = RefreshTokenManager()
    
    private init() {}
    
    private var isScheduled = false
    private var isRefreshing = false
    private var refreshContinuation: [CheckedContinuation<Void, Error>] = []
    private var scheduledTask: Task<Void, Never>?
    
    func refreshIfNeeded() async throws {
        if isRefreshing {
            return try await withCheckedThrowingContinuation { continuation in
                refreshContinuation.append(continuation)
            }
        }
        
        isRefreshing = true
        
        do {
            try await performRefresh()
            completeAllContinuations(with: .success(()))
        } catch {
            completeAllContinuations(with: .failure(error))
            throw error
        }
        
        isRefreshing = false
    }
    
    func scheduleRefresh() {
        guard !isScheduled else { return }
        isScheduled = true
        
        scheduledTask = Task.detached(priority: .utility) {
            guard let token = await TokenStore.shared.getProfileToken(),
                  let expiry = token.jwtExpirationDate() else {
                return // No valid token; skip scheduling
            }
            
            let now = Date()
            let oneDay: TimeInterval = 24 * 60 * 60
            let refreshTime = expiry.addingTimeInterval(-oneDay)
            let delay = max(refreshTime.timeIntervalSince(now), 0)
            
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                // Check if task was cancelled during sleep
                guard !Task.isCancelled else {
                    await self.setIsScheduledFalse()
                    return
                }
                
                try await self.refreshIfNeeded()
            } catch {
                // Handle cancellation or refresh errors gracefully
                if Task.isCancelled {
                    SahhaLogger.info("Refresh token task cancelled")
                } else {
                    SahhaLogger.error("Refresh token failed: \(error.localizedDescription)")
                }
            }
            
            await self.setIsScheduledFalse()
        }
    }
    
    func stop() async {
        // Cancel any scheduled refresh task
        scheduledTask?.cancel()
        scheduledTask = nil
        
        // Cancel any ongoing refresh operations
        completeAllContinuations(with: .failure(CancellationError()))
        
        // Reset state
        isScheduled = false
        isRefreshing = false
        
        SahhaLogger.info("RefreshTokenManager stopped")
    }
    
    private func setIsScheduledFalse() {
        isScheduled = false
        scheduledTask = nil
    }
    
    private func performRefresh() async throws {
        guard let refreshToken = await TokenStore.shared.getRefreshToken() else {
            throw SahhaError.unauthorized
        }
        
        let result = await ApiController.refreshToken(refreshToken)
        switch result {
        case .success(let newTokens):
            try await TokenStore.shared.setTokens(newTokens)
        case .failure(let error):
            throw error
        }
    }
    
    private func completeAllContinuations(with result: Result<Void, Error>) {
        for continuation in refreshContinuation {
            switch result {
            case .success:
                continuation.resume()
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
        refreshContinuation.removeAll()
    }
}
