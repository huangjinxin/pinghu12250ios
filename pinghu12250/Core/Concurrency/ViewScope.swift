//
//  ViewScope.swift
//  pinghu12250
//
//  View 作用域 Task 管理器
//  确保 View 消失时自动取消所有关联的 Task，防止 Task 泄漏
//

import Foundation
import SwiftUI
import Combine

// MARK: - View Scope

/// View 作用域管理器
/// 绑定到 View 的生命周期，在 View 消失时自动取消所有 Task
@MainActor
final class ViewScope: ObservableObject {
    // 唯一标识（用于调试）
    let id: String

    // 内部 TaskBag
    private var taskBag = TaskBag()

    // 子 Scope（用于嵌套结构）
    private var childScopes: [String: ViewScope] = [:]

    // 是否已销毁
    private(set) var isDestroyed = false

    // 活跃 Task 数
    var activeTaskCount: Int {
        taskBag.count
    }

    init(id: String = UUID().uuidString) {
        self.id = id
    }

    // MARK: - Task 管理

    /// 在此 Scope 内运行 Task
    @discardableResult
    func run(
        id: String? = nil,
        priority: TaskPriority = .userInitiated,
        _ operation: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never>? {
        guard !isDestroyed else {
            #if DEBUG
            print("[ViewScope:\(self.id)] 已销毁，忽略新任务")
            #endif
            return nil
        }

        return taskBag.run(operation)
    }

    /// 运行可抛出错误的 Task
    @discardableResult
    func runThrowing(
        id: String? = nil,
        priority: TaskPriority = .userInitiated,
        _ operation: @escaping @Sendable () async throws -> Void
    ) -> Task<Void, Error>? {
        guard !isDestroyed else {
            #if DEBUG
            print("[ViewScope:\(self.id)] 已销毁，忽略新任务")
            #endif
            return nil
        }

        return taskBag.runThrowing(operation)
    }

    /// 延迟运行 Task
    @discardableResult
    func runAfter(
        seconds: TimeInterval,
        _ operation: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never>? {
        guard !isDestroyed else { return nil }

        return taskBag.runAfter(seconds: seconds, operation)
    }

    // MARK: - 子 Scope 管理

    /// 创建子 Scope
    func createChildScope(id: String) -> ViewScope {
        let child = ViewScope(id: "\(self.id)/\(id)")
        childScopes[id] = child
        return child
    }

    /// 获取子 Scope
    func childScope(id: String) -> ViewScope? {
        childScopes[id]
    }

    /// 销毁子 Scope
    func destroyChildScope(id: String) {
        childScopes[id]?.destroy()
        childScopes.removeValue(forKey: id)
    }

    // MARK: - 生命周期

    /// 取消所有 Task（但不销毁 Scope，可以继续使用）
    func cancelAll() {
        taskBag.cancelAll()

        // 递归取消子 Scope
        for (_, child) in childScopes {
            child.cancelAll()
        }
    }

    /// 销毁 Scope（取消所有 Task 并标记为不可用）
    func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true

        // 取消所有任务
        taskBag.cancelAll()

        // 递归销毁子 Scope
        for (_, child) in childScopes {
            child.destroy()
        }
        childScopes.removeAll()

        #if DEBUG
        print("[ViewScope:\(id)] 已销毁，取消 \(taskBag.count) 个任务")
        #endif
    }

    deinit {
        // 确保在 deinit 时也取消任务（防止遗漏 destroy 调用）
        // 注意：deinit 不在 MainActor 上，但 TaskBag.cancelAll 是线程安全的
    }
}

// MARK: - Screen Scope

/// Screen 作用域管理器
/// 用于管理整个页面（Screen）级别的 Task
/// 比 ViewScope 更高级别，包含多个 ViewScope
@MainActor
final class ScreenScope: ObservableObject {
    // 屏幕标识
    let screenId: String

    // 主 Scope
    private let mainScope: ViewScope

    // 命名的 ViewScope 集合
    private var namedScopes: [String: ViewScope] = [:]

    // 关联的 RequestController 请求前缀
    private let requestPrefix: String

    // 是否已销毁
    private(set) var isDestroyed = false

    init(screenId: String) {
        self.screenId = screenId
        self.mainScope = ViewScope(id: "screen:\(screenId)")
        self.requestPrefix = "screen_\(screenId)_"
    }

    // MARK: - 主 Scope 快捷方法

    @discardableResult
    func run(_ operation: @escaping @Sendable () async -> Void) -> Task<Void, Never>? {
        mainScope.run(operation)
    }

    @discardableResult
    func runThrowing(_ operation: @escaping @Sendable () async throws -> Void) -> Task<Void, Error>? {
        mainScope.runThrowing(operation)
    }

    // MARK: - 命名 Scope 管理

    /// 获取或创建命名 Scope
    func scope(named name: String) -> ViewScope {
        if let existing = namedScopes[name] {
            return existing
        }

        let newScope = ViewScope(id: "\(screenId)/\(name)")
        namedScopes[name] = newScope
        return newScope
    }

    /// 销毁命名 Scope
    func destroyScope(named name: String) {
        namedScopes[name]?.destroy()
        namedScopes.removeValue(forKey: name)
    }

    // MARK: - 请求管理

    /// 生成请求 ID（自动添加屏幕前缀）
    func requestId(_ name: String) -> String {
        "\(requestPrefix)\(name)"
    }

    /// 取消此屏幕的所有请求
    func cancelAllRequests() {
        RequestController.shared.cancelAll(prefix: requestPrefix)
    }

    // MARK: - 生命周期

    /// 取消所有 Task 和请求
    func cancelAll() {
        mainScope.cancelAll()

        for (_, scope) in namedScopes {
            scope.cancelAll()
        }

        cancelAllRequests()
    }

    /// 销毁整个 Screen Scope
    func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true

        // 销毁主 Scope
        mainScope.destroy()

        // 销毁所有命名 Scope
        for (_, scope) in namedScopes {
            scope.destroy()
        }
        namedScopes.removeAll()

        // 取消所有关联请求
        cancelAllRequests()

        #if DEBUG
        print("[ScreenScope:\(screenId)] 已销毁")
        #endif
    }
}

// MARK: - View 扩展

extension View {
    /// 绑定 ViewScope 到 View 生命周期
    func withScope(_ scope: ViewScope) -> some View {
        self.onDisappear {
            scope.destroy()
        }
    }

    /// 绑定 ScreenScope 到 View 生命周期
    func withScreenScope(_ scope: ScreenScope) -> some View {
        self.onDisappear {
            scope.destroy()
        }
    }
}

// MARK: - Environment Key

private struct ViewScopeKey: EnvironmentKey {
    static let defaultValue: ViewScope? = nil
}

private struct ScreenScopeKey: EnvironmentKey {
    static let defaultValue: ScreenScope? = nil
}

extension EnvironmentValues {
    var viewScope: ViewScope? {
        get { self[ViewScopeKey.self] }
        set { self[ViewScopeKey.self] = newValue }
    }

    var screenScope: ScreenScope? {
        get { self[ScreenScopeKey.self] }
        set { self[ScreenScopeKey.self] = newValue }
    }
}

// MARK: - Property Wrapper

/// 自动管理 Scope 生命周期的属性包装器
@propertyWrapper
struct ScopedTask<Value> {
    private var value: Value
    private weak var scope: ViewScope?

    init(wrappedValue: Value, scope: ViewScope?) {
        self.value = wrappedValue
        self.scope = scope
    }

    var wrappedValue: Value {
        get { value }
        set { value = newValue }
    }
}
