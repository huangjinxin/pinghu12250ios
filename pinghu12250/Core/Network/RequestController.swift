//
//  RequestController.swift
//  pinghu12250
//
//  请求控制器 - 统一管理网络请求，支持超时和取消
//

import Foundation

// MARK: - 请求控制器

@MainActor
final class RequestController {
    static let shared = RequestController()

    // 活跃的请求任务
    private var activeTasks: [String: Task<Any, Error>] = [:]

    // 请求统计
    private(set) var totalRequests = 0
    private(set) var failedRequests = 0
    private(set) var cancelledRequests = 0

    private init() {}

    // MARK: - 执行请求

    /// 执行带超时的请求
    /// - Parameters:
    ///   - id: 请求唯一标识（用于取消）
    ///   - timeout: 超时时间（秒）
    ///   - essential: 是否为必要请求（非必要请求会在内存警告时被取消）
    ///   - operation: 实际执行的异步操作
    /// - Returns: 操作结果
    func request<T>(
        id: String,
        timeout: TimeInterval = 30,
        essential: Bool = false,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        // 取消同 ID 的旧请求
        cancel(id: id)

        totalRequests += 1

        // 创建带超时的任务
        let task = Task<Any, Error> {
            try await withThrowingTaskGroup(of: T.self) { group in
                // 添加实际操作
                group.addTask {
                    try await operation()
                }

                // 添加超时任务
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    throw RequestError.timeout
                }

                // 等待第一个完成的
                guard let result = try await group.next() else {
                    throw RequestError.unknown
                }

                // 取消其他任务
                group.cancelAll()

                return result
            }
        }

        // 记录任务
        activeTasks[id] = task

        do {
            let result = try await task.value as! T
            activeTasks.removeValue(forKey: id)
            return result
        } catch is CancellationError {
            cancelledRequests += 1
            activeTasks.removeValue(forKey: id)
            throw RequestError.cancelled
        } catch {
            failedRequests += 1
            activeTasks.removeValue(forKey: id)
            throw error
        }
    }

    /// 执行无超时的请求（用于长时间操作）
    func requestNoTimeout<T>(
        id: String,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        cancel(id: id)

        totalRequests += 1

        let task = Task<Any, Error> {
            try await operation()
        }

        activeTasks[id] = task

        do {
            let result = try await task.value as! T
            activeTasks.removeValue(forKey: id)
            return result
        } catch is CancellationError {
            cancelledRequests += 1
            activeTasks.removeValue(forKey: id)
            throw RequestError.cancelled
        } catch {
            failedRequests += 1
            activeTasks.removeValue(forKey: id)
            throw error
        }
    }

    // MARK: - 取消请求

    /// 取消指定请求
    func cancel(id: String) {
        if let task = activeTasks[id] {
            task.cancel()
            activeTasks.removeValue(forKey: id)
        }
    }

    /// 取消所有以指定前缀开头的请求
    func cancelAll(prefix: String) {
        let keysToCancel = activeTasks.keys.filter { $0.hasPrefix(prefix) }
        for key in keysToCancel {
            cancel(id: key)
        }
    }

    /// 取消所有请求
    func cancelAll() {
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
    }

    /// 取消非必要请求（用于内存警告时）
    func cancelNonEssential() {
        // 目前简单实现：取消所有请求
        // 未来可以根据 essential 标记区分
        cancelAll()
    }

    // MARK: - 状态查询

    /// 检查请求是否正在进行
    func isActive(id: String) -> Bool {
        activeTasks[id] != nil
    }

    /// 当前活跃请求数
    var activeCount: Int {
        activeTasks.count
    }

    /// 获取所有活跃请求 ID
    var activeRequestIds: [String] {
        Array(activeTasks.keys)
    }

    /// 重置统计
    func resetStats() {
        totalRequests = 0
        failedRequests = 0
        cancelledRequests = 0
    }
}

// MARK: - 请求错误类型

enum RequestError: LocalizedError {
    case timeout
    case cancelled
    case unknown

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "请求超时"
        case .cancelled:
            return "请求已取消"
        case .unknown:
            return "未知错误"
        }
    }
}

// MARK: - 便捷方法

extension RequestController {
    /// 快速执行 GET 请求
    func get<T: Decodable>(
        id: String,
        url: URL,
        timeout: TimeInterval = 30
    ) async throws -> T {
        try await request(id: id, timeout: timeout) {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw RequestError.unknown
            }

            return try JSONDecoder().decode(T.self, from: data)
        }
    }

    /// 快速执行 POST 请求
    func post<T: Decodable, B: Encodable>(
        id: String,
        url: URL,
        body: B,
        timeout: TimeInterval = 30
    ) async throws -> T {
        try await request(id: id, timeout: timeout) {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw RequestError.unknown
            }

            return try JSONDecoder().decode(T.self, from: data)
        }
    }
}

// MARK: - 请求 ID 命名规范

extension RequestController {
    /// 请求 ID 前缀
    enum RequestPrefix {
        static let auth = "auth_"
        static let textbook = "textbook_"
        static let ai = "ai_"
        static let practice = "practice_"
        static let notes = "notes_"
        static let download = "download_"
    }
}
