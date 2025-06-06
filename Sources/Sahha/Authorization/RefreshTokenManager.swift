import Foundation

final actor RefreshTokenManager {
    static let shared = RefreshTokenManager()
    
    private init() {}
    
    private var isScheduled = false
    private var isRefreshing = false
    private var refreshContinuation: [CheckedContinuation<Void, Error>] = []
    
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
        
        Task.detached(priority: .utility) {
            guard let token = await TokenStore.shared.getProfileToken(),
                  let expiry = token.jwtExpirationDate() else {
                return // No valid token; skip scheduling
            }
            
            let now = Date()
            let oneDay: TimeInterval = 24 * 60 * 60
            let refreshTime = expiry.addingTimeInterval(-oneDay)
            let delay = max(refreshTime.timeIntervalSince(now), 0)
            
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            try? await self.refreshIfNeeded()
            
            await self.setIsScheduledFalse()
        }
    }
    
    private func setIsScheduledFalse() {
        isScheduled = false
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
