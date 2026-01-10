//
//  PaginationController.swift
//  pinghu12250
//
//  分页请求控制器 - 防抖、去重、状态管理
//

import Foundation

// MARK: - 分页请求控制器

@MainActor
final class PaginationController {
    // 默认防抖延迟
    private let defaultDebounceDelay: TimeInterval = 0.3

    // 当前待执行的请求任务
    private var pendingTask: Task<Void, Never>?

    // 正在执行的请求 ID（用于去重）
    private var executingRequestId: String?

    // 是否正在加载
    private(set) var isLoading = false

    // 最后一次请求的时间
    private var lastRequestTime: Date?

    // MARK: - 初始化

    init() {}

    // MARK: - 请求方法

    /// 发起分页加载请求（带防抖）
    /// - Parameters:
    ///   - requestId: 请求唯一标识（相同ID的请求会被去重）
    ///   - delay: 防抖延迟，默认300ms
    ///   - action: 实际执行的加载操作
    func loadMore(
        requestId: String = "default",
        delay: TimeInterval? = nil,
        action: @escaping () async -> Void
    ) {
        let actualDelay = delay ?? defaultDebounceDelay

        // 如果相同ID的请求正在执行，直接返回
        if executingRequestId == requestId && isLoading {
            return
        }

        // 取消之前的待执行任务
        pendingTask?.cancel()

        // 创建新的防抖任务
        pendingTask = Task { [weak self] in
            // 等待防抖延迟
            do {
                try await Task.sleep(nanoseconds: UInt64(actualDelay * 1_000_000_000))
            } catch {
                // 任务被取消
                return
            }

            // 检查是否被取消
            guard !Task.isCancelled else { return }

            // 再次检查是否有相同请求正在执行
            guard self?.executingRequestId != requestId || self?.isLoading != true else {
                return
            }

            // 标记开始执行
            self?.executingRequestId = requestId
            self?.isLoading = true
            self?.lastRequestTime = Date()

            // 执行实际请求
            await action()

            // 标记执行完成
            self?.isLoading = false
            self?.executingRequestId = nil
        }
    }

    /// 立即执行请求（不防抖，但仍然去重）
    func loadImmediately(
        requestId: String = "default",
        action: @escaping () async -> Void
    ) {
        // 如果相同ID的请求正在执行，直接返回
        if executingRequestId == requestId && isLoading {
            return
        }

        // 取消待执行的防抖任务
        pendingTask?.cancel()

        // 立即执行
        pendingTask = Task { [weak self] in
            self?.executingRequestId = requestId
            self?.isLoading = true
            self?.lastRequestTime = Date()

            await action()

            self?.isLoading = false
            self?.executingRequestId = nil
        }
    }

    /// 取消当前待执行的请求
    func cancel() {
        pendingTask?.cancel()
        pendingTask = nil
    }

    /// 重置状态
    func reset() {
        cancel()
        isLoading = false
        executingRequestId = nil
        lastRequestTime = nil
    }
}

// MARK: - 分页状态管理

/// 分页状态
struct PaginationState<T> {
    var items: [T] = []
    var currentPage: Int = 1
    var pageSize: Int = 20
    var totalCount: Int = 0
    var hasMore: Bool = true
    var isLoading: Bool = false
    var error: Error?

    var isEmpty: Bool {
        items.isEmpty && !isLoading
    }

    var canLoadMore: Bool {
        hasMore && !isLoading
    }

    mutating func reset() {
        items = []
        currentPage = 1
        totalCount = 0
        hasMore = true
        isLoading = false
        error = nil
    }

    mutating func appendPage(_ newItems: [T], total: Int? = nil) {
        items.append(contentsOf: newItems)
        currentPage += 1

        if let total = total {
            totalCount = total
            hasMore = items.count < total
        } else {
            hasMore = newItems.count >= pageSize
        }
    }

    mutating func replacePage(_ newItems: [T], total: Int? = nil) {
        items = newItems
        currentPage = 1

        if let total = total {
            totalCount = total
            hasMore = items.count < total
        } else {
            hasMore = newItems.count >= pageSize
        }
    }
}

// MARK: - 通用分页加载器

@MainActor
final class PaginationLoader<T> {
    private let controller = PaginationController()
    private(set) var state = PaginationState<T>()

    /// 加载下一页
    func loadNextPage(
        loader: @escaping (Int, Int) async throws -> (items: [T], total: Int?)
    ) {
        guard state.canLoadMore else { return }

        controller.loadMore(requestId: "page_\(state.currentPage)") { [weak self] in
            guard let self = self else { return }

            self.state.isLoading = true
            self.state.error = nil

            do {
                let result = try await loader(self.state.currentPage, self.state.pageSize)
                self.state.appendPage(result.items, total: result.total)
            } catch {
                self.state.error = error
            }

            self.state.isLoading = false
        }
    }

    /// 刷新（重新加载第一页）
    func refresh(
        loader: @escaping (Int, Int) async throws -> (items: [T], total: Int?)
    ) {
        controller.loadImmediately(requestId: "refresh") { [weak self] in
            guard let self = self else { return }

            self.state.isLoading = true
            self.state.error = nil
            self.state.currentPage = 1

            do {
                let result = try await loader(1, self.state.pageSize)
                self.state.replacePage(result.items, total: result.total)
            } catch {
                self.state.error = error
            }

            self.state.isLoading = false
        }
    }

    /// 取消加载
    func cancel() {
        controller.cancel()
        state.isLoading = false
    }

    /// 重置
    func reset() {
        controller.reset()
        state.reset()
    }
}
