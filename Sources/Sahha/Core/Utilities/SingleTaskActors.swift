import Foundation

/// Ensures that only one instance of an async task (with no errors) is executing at a time.
/// If a second caller requests a run while a task is in-flight, it will await the existing result.
/// Useful for deduplication of async work such as background syncs, uploads, etc.
actor SingleTaskActor<Output: Sendable> {
    private var currentTask: Task<Output, Never>?

    /// Runs the given operation if no task is in progress, otherwise awaits the current task's result.
    /// - Parameter operation: The async closure to run.
    /// - Returns: The output of the operation.
    func run(operation: @Sendable @escaping () async -> Output) async -> Output {
        if let existingTask = currentTask {
            // A task is already running; wait for its result
            return await existingTask.value
        }
        let task = Task {
            defer { self.clearTask() }
            return await operation()
        }
        currentTask = task
        return await task.value
    }
    
    func cancel() {
           currentTask?.cancel()
           currentTask = nil
       }

       func isRunning() -> Bool {
           currentTask != nil
       }

    /// Clears the current task reference when done.
    private func clearTask() {
        currentTask = nil
    }
}

/// Like SingleTaskActor, but supports throwing tasks.
/// Ensures only one instance of a throwing async operation is running at once.
actor SingleThrowingTaskActor<Output: Sendable> {
    private var currentTask: Task<Output, Error>?
    private var generation: UInt64 = 0

    /// Runs the given throwing operation if no task is in progress, otherwise awaits the current task's result.
    /// - Parameter operation: The async closure to run.
    /// - Throws: Rethrows any error from the operation.
    /// - Returns: The output of the operation.
    func run(operation: @Sendable @escaping () async throws -> Output) async throws -> Output {
        if let existingTask = currentTask {
            // A task is already running; wait for its result
            return try await existingTask.value
        }
        generation &+= 1
        let taskGeneration = generation
        let task = Task {
            defer { self.clearTask(ifGeneration: taskGeneration) }
            return try await operation()
        }
        currentTask = task
        return try await task.value
    }

    func cancel() {
           currentTask?.cancel()
           currentTask = nil
           // Invalidate the cancelled flight's pending clearTask: a cancelled task can unwind
           // *after* a new flight registers, and its stale defer must not clobber that
           // registration (which would let two flights run concurrently).
           generation &+= 1
       }

       func isRunning() -> Bool {
           currentTask != nil
       }

    /// Clears the current task reference when done, unless a newer flight has replaced it.
    private func clearTask(ifGeneration taskGeneration: UInt64) {
        guard taskGeneration == generation else { return }
        currentTask = nil
    }
}

/// Ensures only one instance of an async task is running **per unique key** (no errors).
/// For example, deduplicates requests for different resources by key.
actor SingleTaskActorMap<Key: Hashable, Output: Sendable> {
    private var tasks: [Key: Task<Output, Never>] = [:]

    /// Runs the operation for the given key if no task is in progress for that key,
    /// otherwise awaits the existing task's result for that key.
    /// - Parameters:
    ///   - key: The key representing the task's uniqueness.
    ///   - operation: The async closure to run.
    /// - Returns: The output of the operation.
    func run(for key: Key, operation: @Sendable @escaping () async -> Output) async -> Output {
        if let existingTask = tasks[key] {
            // Task is already running for this key; wait for its result
            return await existingTask.value
        }
        let task = Task {
            defer { self.clearTask(for: key) }
            return await operation()
        }
        tasks[key] = task
        return await task.value
    }
    
    func cancel(for key: Key) {
            tasks[key]?.cancel()
            tasks[key] = nil
        }

        func cancelAll() {
            for (_, task) in tasks {
                task.cancel()
            }
            tasks.removeAll()
        }

        func isRunning(for key: Key) -> Bool {
            tasks[key] != nil
        }

    /// Clears the task reference for the given key when done.
    private func clearTask(for key: Key) {
        tasks[key] = nil
    }
}

/// Like SingleTaskActorMap, but supports throwing tasks per unique key.
/// Ensures only one instance of a throwing async operation is running at once for each key.
actor SingleThrowingTaskActorMap<Key: Hashable, Output: Sendable> {
    private var tasks: [Key: Task<Output, Error>] = [:]

    /// Runs the throwing operation for the given key if no task is in progress for that key,
    /// otherwise awaits the existing task's result for that key.
    /// - Parameters:
    ///   - key: The key representing the task's uniqueness.
    ///   - operation: The async throwing closure to run.
    /// - Throws: Rethrows any error from the operation.
    /// - Returns: The output of the operation.
    func run(for key: Key, operation: @Sendable @escaping () async throws -> Output) async throws -> Output {
        if let existingTask = tasks[key] {
            // Task is already running for this key; wait for its result
            return try await existingTask.value
        }
        let task = Task {
            defer { self.clearTask(for: key) }
            return try await operation()
        }
        tasks[key] = task
        return try await task.value
    }
    
    func cancel(for key: Key) {
            tasks[key]?.cancel()
            tasks[key] = nil
        }

        func cancelAll() {
            for (_, task) in tasks {
                task.cancel()
            }
            tasks.removeAll()
        }

        func isRunning(for key: Key) -> Bool {
            tasks[key] != nil
        }

    /// Clears the task reference for the given key when done.
    private func clearTask(for key: Key) {
        tasks[key] = nil
    }
}
