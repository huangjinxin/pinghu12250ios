//
//  ErrorBoundary.swift
//  pinghu12250
//
//  错误边界组件 - 隔离模块错误，防止一个模块崩溃影响整个应用
//

import SwiftUI

// MARK: - 错误边界视图

/// 错误边界视图 - 捕获子视图的错误并显示降级UI
struct ErrorBoundaryView<Content: View>: View {
    let content: () -> Content
    let onError: ((Error) -> Void)?

    @State private var hasError = false
    @State private var retryCount = 0

    private let maxRetries = 3

    init(
        onError: ((Error) -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
        self.onError = onError
    }

    var body: some View {
        if hasError {
            errorFallbackView
        } else {
            content()
        }
    }

    // 简洁的错误提示视图
    private var errorFallbackView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("加载失败")
                .font(.headline)
                .foregroundColor(.primary)

            if retryCount < maxRetries {
                Button(action: retry) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("重试")
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("请稍后再试")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private func retry() {
        retryCount += 1
        hasError = false
    }

    /// 触发错误状态
    func triggerError(_ error: Error) {
        hasError = true
        onError?(error)
    }
}

// MARK: - View 扩展

extension View {
    /// 包裹视图在错误边界中
    func withErrorBoundary(onError: ((Error) -> Void)? = nil) -> some View {
        ErrorBoundaryView(onError: onError) {
            self
        }
    }
}

// MARK: - 异步任务错误边界

/// 带异步加载的错误边界
struct AsyncErrorBoundary<Content: View, LoadingView: View>: View {
    let loader: () async throws -> Void
    let content: () -> Content
    let loadingView: () -> LoadingView
    let onError: ((Error) -> Void)?

    @State private var isLoading = true
    @State private var hasError = false
    @State private var errorMessage: String?
    @State private var retryCount = 0

    private let maxRetries = 3

    init(
        loader: @escaping () async throws -> Void,
        onError: ((Error) -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder loadingView: @escaping () -> LoadingView
    ) {
        self.loader = loader
        self.onError = onError
        self.content = content
        self.loadingView = loadingView
    }

    var body: some View {
        Group {
            if isLoading {
                loadingView()
            } else if hasError {
                errorFallbackView
            } else {
                content()
            }
        }
        .task {
            await load()
        }
    }

    private var errorFallbackView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("加载失败")
                .font(.headline)

            if let message = errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if retryCount < maxRetries {
                Button(action: { Task { await retry() } }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("重试")
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() async {
        isLoading = true
        hasError = false
        errorMessage = nil

        do {
            try await loader()
            isLoading = false
        } catch {
            hasError = true
            errorMessage = error.localizedDescription
            isLoading = false
            onError?(error)
        }
    }

    private func retry() async {
        retryCount += 1
        await load()
    }
}

// MARK: - 便捷初始化

extension AsyncErrorBoundary where LoadingView == ProgressView<EmptyView, EmptyView> {
    init(
        loader: @escaping () async throws -> Void,
        onError: ((Error) -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.loader = loader
        self.onError = onError
        self.content = content
        self.loadingView = { ProgressView() }
    }
}

// MARK: - 看门狗与内存管理通知

extension Notification.Name {
    // MARK: - 三级 Watchdog 通知

    /// Level 1: 主线程阻塞 >2s，已记录快照
    static let watchdogLevel1 = Notification.Name("watchdogLevel1")

    /// Level 2: 主线程阻塞 >3s，已取消所有任务
    static let watchdogLevel2 = Notification.Name("watchdogLevel2")

    /// Level 3: 主线程阻塞 >4s，需要重置状态
    static let watchdogLevel3 = Notification.Name("watchdogLevel3")

    /// 兼容旧版：通用恢复通知（等同于 Level 2）
    static let watchdogRecovery = Notification.Name("watchdogRecovery")

    // MARK: - 内存水位通知

    /// 内存水位 70%：停止预加载
    static let memoryLevel70 = Notification.Name("memoryLevel70")

    /// 内存水位 80%：暂停 AI 流式输出
    static let memoryLevel80 = Notification.Name("memoryLevel80")

    /// 内存水位 90%：紧急清理
    static let memoryLevel90 = Notification.Name("memoryLevel90")

    /// 内存水位恢复正常（<60%）
    static let memoryLevelNormal = Notification.Name("memoryLevelNormal")
}

// MARK: - 可恢复的错误边界

/// 支持看门狗恢复的错误边界
struct RecoverableErrorBoundary<Content: View>: View {
    let content: () -> Content
    let onRecovery: (() -> Void)?

    @State private var hasError = false
    @State private var isRecovering = false

    init(
        onRecovery: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
        self.onRecovery = onRecovery
    }

    var body: some View {
        Group {
            if isRecovering {
                recoveryView
            } else if hasError {
                errorView
            } else {
                content()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchdogRecovery)) { _ in
            triggerRecovery()
        }
    }

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("加载失败")
                .font(.headline)

            Button("重试") {
                hasError = false
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var recoveryView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("正在恢复...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // 延迟恢复
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                isRecovering = false
                onRecovery?()
            }
        }
    }

    private func triggerRecovery() {
        isRecovering = true
    }

    func triggerError() {
        hasError = true
    }
}
