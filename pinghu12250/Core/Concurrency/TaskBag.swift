//
//  TaskBag.swift
//  pinghu12250
//
//  Task 生命周期管理 - 自动取消未完成的 Task
//

import Foundation
import SwiftUI
import Combine

// MARK: - Task 容器

/// Task 容器，自动管理 Task 生命周期
/// 在 deinit 时自动取消所有未完成的任务
@MainActor
final class TaskBag {
    private var tasks: [Task<Void, Never>] = []
    private var throwingTasks: [Task<Void, Error>] = []

    init() {}

    /// 添加一个不抛出错误的 Task
    func add(_ task: Task<Void, Never>) {
        // 清理已完成的任务
        tasks.removeAll { $0.isCancelled }
        tasks.append(task)
    }

    /// 添加一个可能抛出错误的 Task
    func addThrowing(_ task: Task<Void, Error>) {
        throwingTasks.removeAll { $0.isCancelled }
        throwingTasks.append(task)
    }

    /// 取消所有任务
    func cancelAll() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()

        throwingTasks.forEach { $0.cancel() }
        throwingTasks.removeAll()
    }

    /// 当前活跃任务数
    var count: Int {
        tasks.count + throwingTasks.count
    }

    deinit {
        // 在 deinit 中取消所有任务
        for task in tasks {
            task.cancel()
        }
        for task in throwingTasks {
            task.cancel()
        }
    }
}

// MARK: - 便捷方法

extension TaskBag {
    /// 创建并添加一个 Task
    @discardableResult
    func run(_ operation: @escaping @Sendable () async -> Void) -> Task<Void, Never> {
        let task = Task { await operation() }
        add(task)
        return task
    }

    /// 创建并添加一个可能抛出错误的 Task
    @discardableResult
    func runThrowing(_ operation: @escaping @Sendable () async throws -> Void) -> Task<Void, Error> {
        let task = Task { try await operation() }
        addThrowing(task)
        return task
    }

    /// 延迟执行
    @discardableResult
    func runAfter(
        seconds: TimeInterval,
        _ operation: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> {
        let task = Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await operation()
        }
        add(task)
        return task
    }
}

// MARK: - View 扩展

extension View {
    /// 在 View 生命周期内执行异步操作
    /// 与 .task 不同，这个版本在 View 消失时会取消任务
    func onAppearAsync(
        id: String = UUID().uuidString,
        priority: TaskPriority = .userInitiated,
        _ action: @escaping () async -> Void
    ) -> some View {
        modifier(AsyncOnAppearModifier(id: id, priority: priority, action: action))
    }

    /// 带加载状态的异步操作
    func onAppearAsync(
        isLoading: Binding<Bool>,
        _ action: @escaping () async -> Void
    ) -> some View {
        modifier(AsyncLoadingModifier(isLoading: isLoading, action: action))
    }

    /// 添加看门狗恢复处理
    func onWatchdogRecovery(_ action: @escaping () -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: .watchdogRecovery)) { _ in
            action()
        }
    }
}

// MARK: - View Modifiers

private struct AsyncOnAppearModifier: ViewModifier {
    let id: String
    let priority: TaskPriority
    let action: () async -> Void

    @State private var task: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onAppear {
                task = Task(priority: priority) {
                    await action()
                }
            }
            .onDisappear {
                task?.cancel()
                task = nil
            }
    }
}

private struct AsyncLoadingModifier: ViewModifier {
    @Binding var isLoading: Bool
    let action: () async -> Void

    @State private var task: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onAppear {
                task = Task {
                    isLoading = true
                    await action()
                    isLoading = false
                }
            }
            .onDisappear {
                task?.cancel()
                task = nil
            }
    }
}

// MARK: - 带取消功能的按钮

/// 异步按钮，支持加载状态和自动取消
struct AsyncButton<Label: View>: View {
    let action: () async -> Void
    let label: () -> Label

    @State private var isLoading = false
    @State private var task: Task<Void, Never>?

    init(
        action: @escaping () async -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.action = action
        self.label = label
    }

    var body: some View {
        Button {
            guard !isLoading else { return }

            task = Task {
                isLoading = true
                await action()
                isLoading = false
            }
        } label: {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                label()
            }
        }
        .disabled(isLoading)
        .onDisappear {
            task?.cancel()
        }
    }
}

// MARK: - 带取消功能的列表加载

/// 滚动到底部时自动加载更多
struct InfiniteScrollView<Content: View, Item: Identifiable>: View {
    let items: [Item]
    let hasMore: Bool
    let isLoading: Bool
    let loadMore: () async -> Void
    let content: (Item) -> Content

    @State private var loadTask: Task<Void, Never>?

    init(
        items: [Item],
        hasMore: Bool,
        isLoading: Bool,
        loadMore: @escaping () async -> Void,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.hasMore = hasMore
        self.isLoading = isLoading
        self.loadMore = loadMore
        self.content = content
    }

    var body: some View {
        LazyVStack {
            ForEach(items) { item in
                content(item)
                    .onAppear {
                        // 当显示最后一个元素时，触发加载更多
                        if item.id as AnyHashable == items.last?.id as AnyHashable {
                            triggerLoadMore()
                        }
                    }
            }

            if isLoading {
                ProgressView()
                    .padding()
            }
        }
        .onDisappear {
            loadTask?.cancel()
        }
    }

    private func triggerLoadMore() {
        guard hasMore, !isLoading else { return }

        loadTask?.cancel()
        loadTask = Task {
            await loadMore()
        }
    }
}
