import Foundation

enum LifecycleQueues {
    static let `default`: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.sahha.lifecycleEventQueue"
        queue.qualityOfService = .utility
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    static let background: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.sahha.lifecycleBackgroundQueue"
        queue.qualityOfService = .background
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
}
