//
//  AsyncSemaphore.swift
//  pinghu12250
//
//  并发控制信号量 - 限制同时执行的任务数量
//

import Foundation

/// 异步信号量，用于限制并发任务数量
actor AsyncSemaphore {
    private var permits: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    /// 初始化信号量
    /// - Parameter value: 最大并发数
    init(value: Int) {
        self.permits = value
    }

    /// 获取一个许可（如果没有可用许可则等待）
    func wait() async {
        if permits > 0 {
            permits -= 1
            return
        }

        // 没有可用许可，需要等待
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    /// 尝试获取许可（非阻塞）
    /// - Returns: 是否成功获取
    func tryWait() -> Bool {
        if permits > 0 {
            permits -= 1
            return true
        }
        return false
    }

    /// 释放一个许可
    func signal() {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume()
        } else {
            permits += 1
        }
    }

    /// 当前可用许可数
    var availablePermits: Int {
        permits
    }

    /// 等待中的任务数
    var waitingCount: Int {
        waiters.count
    }
}

// MARK: - 带超时的信号量扩展

extension AsyncSemaphore {
    /// 带超时的等待
    /// - Parameter timeout: 超时时间（秒）
    /// - Returns: 是否在超时前获取到许可
    func wait(timeout: TimeInterval) async -> Bool {
        // 先尝试非阻塞获取
        if tryWait() {
            return true
        }

        // 创建超时任务
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            return false
        }

        // 创建等待任务
        let waitTask = Task {
            await wait()
            return true
        }

        // 等待第一个完成的
        let result = await withTaskGroup(of: Bool.self) { group in
            group.addTask { await waitTask.value }
            group.addTask { (try? await timeoutTask.value) ?? false }

            if let first = await group.next() {
                group.cancelAll()
                return first
            }
            return false
        }

        if !result {
            // 超时了，但等待任务可能还在队列中
            // 这里简化处理，实际使用中需要更复杂的取消机制
            waitTask.cancel()
        }

        return result
    }
}

// MARK: - 便捷的资源守护

/// 使用信号量保护的资源访问
func withSemaphore<T>(_ semaphore: AsyncSemaphore, operation: () async throws -> T) async rethrows -> T {
    await semaphore.wait()
    defer { Task { await semaphore.signal() } }
    return try await operation()
}
