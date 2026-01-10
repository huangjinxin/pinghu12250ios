//
//  ThrottledPublisher.swift
//  pinghu12250
//
//  状态节流发布器 - 防止高频 @Published 更新导致 UI 饥饿
//  用于 AI 流式输出、PDF 翻页等高频状态变化场景
//

import Foundation
import Combine

// MARK: - 节流状态包装器

/// 对高频变化的状态进行节流，避免 View 过度刷新
/// 典型场景：AI 流式输出、滚动位置、动画进度
@MainActor
final class ThrottledState<T: Equatable>: ObservableObject {
    /// 节流后的值（View 应订阅此属性）
    @Published private(set) var value: T

    /// 节流间隔（毫秒）
    private let intervalMs: Int

    /// 上次更新时间
    private var lastUpdateTime: UInt64 = 0

    /// 待更新的值
    private var pendingValue: T?

    /// 更新任务
    private var updateTask: Task<Void, Never>?

    /// 是否启用去重（相同值不触发更新）
    private let removeDuplicates: Bool

    init(initial: T, intervalMs: Int = 100, removeDuplicates: Bool = true) {
        self.value = initial
        self.intervalMs = intervalMs
        self.removeDuplicates = removeDuplicates
    }

    /// 更新值（会被节流）
    func update(_ newValue: T) {
        // 去重检查
        if removeDuplicates && newValue == value {
            return
        }

        let now = DispatchTime.now().uptimeNanoseconds
        let elapsed = (now - lastUpdateTime) / 1_000_000 // 转换为毫秒

        if elapsed >= UInt64(intervalMs) {
            // 超过节流间隔，立即更新
            applyUpdate(newValue)
        } else {
            // 在节流间隔内，记录待更新值
            pendingValue = newValue
            scheduleDelayedUpdate()
        }
    }

    /// 强制立即更新（用于关键状态变化）
    func forceUpdate(_ newValue: T) {
        updateTask?.cancel()
        pendingValue = nil
        applyUpdate(newValue)
    }

    private func applyUpdate(_ newValue: T) {
        value = newValue
        lastUpdateTime = DispatchTime.now().uptimeNanoseconds
    }

    private func scheduleDelayedUpdate() {
        // 避免重复调度
        guard updateTask == nil else { return }

        updateTask = Task { [weak self] in
            guard let self = self else { return }

            // 等待剩余的节流时间
            let now = DispatchTime.now().uptimeNanoseconds
            let elapsed = (now - self.lastUpdateTime) / 1_000_000
            let remaining = UInt64(self.intervalMs) - elapsed

            if remaining > 0 {
                try? await Task.sleep(nanoseconds: remaining * 1_000_000)
            }

            // 检查是否取消
            guard !Task.isCancelled else { return }

            // 应用待更新的值
            if let pending = self.pendingValue {
                self.pendingValue = nil
                self.applyUpdate(pending)
            }

            self.updateTask = nil
        }
    }

    deinit {
        updateTask?.cancel()
    }
}

// MARK: - 字符串累积节流器

/// 专门用于 AI 流式输出的字符串累积节流器
/// 特性：累积字符直到节流间隔到达，一次性刷新
@MainActor
final class StreamingTextThrottle: ObservableObject {
    /// 节流后的完整文本（View 应订阅此属性）
    @Published private(set) var text: String = ""

    /// 节流间隔（毫秒）
    private let intervalMs: Int

    /// 累积缓冲区
    private var buffer: String = ""

    /// 上次刷新时间
    private var lastFlushTime: UInt64 = 0

    /// 刷新任务
    private var flushTask: Task<Void, Never>?

    /// 是否正在流式输出中
    @Published private(set) var isStreaming = false

    init(intervalMs: Int = 80) {
        self.intervalMs = intervalMs
    }

    /// 开始新的流式输出
    func startStream() {
        flushTask?.cancel()
        buffer = ""
        text = ""
        isStreaming = true
        lastFlushTime = DispatchTime.now().uptimeNanoseconds
    }

    /// 追加内容（会被节流）
    func append(_ chunk: String) {
        buffer.append(chunk)

        let now = DispatchTime.now().uptimeNanoseconds
        let elapsed = (now - lastFlushTime) / 1_000_000

        // 检查是否应该立即刷新
        let shouldFlushNow = elapsed >= UInt64(intervalMs)
            || chunk.contains(where: { "。，！？；：\n".contains($0) }) // 遇到标点立即刷新

        if shouldFlushNow {
            flush()
        } else {
            scheduleFlush()
        }
    }

    /// 结束流式输出
    func endStream() {
        flushTask?.cancel()
        flush()
        isStreaming = false
    }

    /// 强制刷新缓冲区
    func flush() {
        guard !buffer.isEmpty else { return }
        text.append(buffer)
        buffer = ""
        lastFlushTime = DispatchTime.now().uptimeNanoseconds
    }

    private func scheduleFlush() {
        guard flushTask == nil else { return }

        flushTask = Task { [weak self] in
            guard let self = self else { return }

            let now = DispatchTime.now().uptimeNanoseconds
            let elapsed = (now - self.lastFlushTime) / 1_000_000
            let remaining = UInt64(self.intervalMs) - elapsed

            if remaining > 0 {
                try? await Task.sleep(nanoseconds: remaining * 1_000_000)
            }

            guard !Task.isCancelled else { return }

            self.flush()
            self.flushTask = nil
        }
    }

    /// 重置状态
    func reset() {
        flushTask?.cancel()
        flushTask = nil
        buffer = ""
        text = ""
        isStreaming = false
    }

    deinit {
        flushTask?.cancel()
    }
}

// MARK: - Combine Publisher 扩展

extension Publisher where Failure == Never {
    /// 节流 + 去重，适用于 @Published 属性
    func throttledUnique(
        for interval: DispatchQueue.SchedulerTimeType.Stride
    ) -> AnyPublisher<Output, Never> where Output: Equatable {
        self
            .removeDuplicates()
            .throttle(for: interval, scheduler: DispatchQueue.main, latest: true)
            .eraseToAnyPublisher()
    }

    /// 防抖，适用于用户输入
    func debouncedUnique(
        for interval: DispatchQueue.SchedulerTimeType.Stride
    ) -> AnyPublisher<Output, Never> where Output: Equatable {
        self
            .removeDuplicates()
            .debounce(for: interval, scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

// MARK: - 音频电平节流器

/// 专门用于音频电平显示的节流器
/// 特性：高频更新（50ms）但只在变化超过阈值时刷新 UI
@MainActor
final class AudioLevelThrottle: ObservableObject {
    /// 节流后的电平值（View 应订阅此属性）
    @Published private(set) var displayLevel: Float = 0

    /// 节流间隔（毫秒）
    private let intervalMs: Int

    /// 变化阈值（电平变化超过此值才刷新）
    private let changeThreshold: Float

    /// 上次更新时间
    private var lastUpdateTime: UInt64 = 0

    /// 更新任务
    private var updateTask: Task<Void, Never>?

    init(intervalMs: Int = 100, changeThreshold: Float = 0.05) {
        self.intervalMs = intervalMs
        self.changeThreshold = changeThreshold
    }

    /// 更新电平值
    func update(_ level: Float) {
        // 变化阈值检查
        if abs(level - displayLevel) < changeThreshold {
            return
        }

        let now = DispatchTime.now().uptimeNanoseconds
        let elapsed = (now - lastUpdateTime) / 1_000_000

        if elapsed >= UInt64(intervalMs) {
            applyUpdate(level)
        } else {
            scheduleUpdate(level)
        }
    }

    private func applyUpdate(_ level: Float) {
        displayLevel = level
        lastUpdateTime = DispatchTime.now().uptimeNanoseconds
    }

    private func scheduleUpdate(_ level: Float) {
        updateTask?.cancel()

        updateTask = Task { [weak self] in
            guard let self = self else { return }

            let remaining = UInt64(self.intervalMs) * 1_000_000
            try? await Task.sleep(nanoseconds: remaining)

            guard !Task.isCancelled else { return }

            self.applyUpdate(level)
            self.updateTask = nil
        }
    }

    /// 重置
    func reset() {
        updateTask?.cancel()
        updateTask = nil
        displayLevel = 0
        lastUpdateTime = 0
    }

    deinit {
        updateTask?.cancel()
    }
}

// MARK: - 波形数据节流器

/// 专门用于波形显示的节流器
/// 特性：累积采样点，批量更新
@MainActor
final class WaveformThrottle: ObservableObject {
    /// 节流后的波形数据（View 应订阅此属性）
    @Published private(set) var samples: [Float] = []

    /// 最大样本数
    private let maxSamples: Int

    /// 节流间隔（毫秒）
    private let intervalMs: Int

    /// 缓冲区
    private var buffer: [Float] = []

    /// 上次刷新时间
    private var lastFlushTime: UInt64 = 0

    /// 刷新任务
    private var flushTask: Task<Void, Never>?

    init(maxSamples: Int = 300, intervalMs: Int = 150) {
        self.maxSamples = maxSamples
        self.intervalMs = intervalMs
    }

    /// 添加采样点
    func append(_ sample: Float) {
        buffer.append(sample)

        let now = DispatchTime.now().uptimeNanoseconds
        let elapsed = (now - lastFlushTime) / 1_000_000

        // 累积一定数量或超过时间间隔才刷新
        if buffer.count >= 3 || elapsed >= UInt64(intervalMs) {
            flush()
        } else {
            scheduleFlush()
        }
    }

    private func flush() {
        guard !buffer.isEmpty else { return }

        // 限制最大样本数
        let newSamples = samples + buffer
        if newSamples.count > maxSamples {
            samples = Array(newSamples.suffix(maxSamples))
        } else {
            samples = newSamples
        }

        buffer = []
        lastFlushTime = DispatchTime.now().uptimeNanoseconds
    }

    private func scheduleFlush() {
        guard flushTask == nil else { return }

        flushTask = Task { [weak self] in
            guard let self = self else { return }

            try? await Task.sleep(nanoseconds: UInt64(self.intervalMs) * 1_000_000)

            guard !Task.isCancelled else { return }

            self.flush()
            self.flushTask = nil
        }
    }

    /// 重置
    func reset() {
        flushTask?.cancel()
        flushTask = nil
        samples = []
        buffer = []
        lastFlushTime = 0
    }

    deinit {
        flushTask?.cancel()
    }
}

// MARK: - 页码节流状态

/// 专门用于 PDF 翻页的节流状态
/// 特性：快速翻页时只更新最终页码，避免中间页渲染
@MainActor
final class PageNumberThrottle: ObservableObject {
    /// 节流后的页码（View 应订阅此属性）
    @Published private(set) var displayPage: Int = 1

    /// 实际页码（内部使用）
    private var actualPage: Int = 1

    /// 节流间隔（毫秒）
    private let intervalMs: Int

    /// 上次更新时间
    private var lastUpdateTime: UInt64 = 0

    /// 更新任务
    private var updateTask: Task<Void, Never>?

    /// 是否正在快速翻页
    @Published private(set) var isRapidPaging = false

    init(initialPage: Int = 1, intervalMs: Int = 120) {
        self.displayPage = initialPage
        self.actualPage = initialPage
        self.intervalMs = intervalMs
    }

    /// 更新页码
    func updatePage(_ page: Int) {
        guard page != actualPage else { return }
        actualPage = page

        let now = DispatchTime.now().uptimeNanoseconds
        let elapsed = (now - lastUpdateTime) / 1_000_000

        if elapsed >= UInt64(intervalMs) {
            applyUpdate()
        } else {
            isRapidPaging = true
            scheduleUpdate()
        }
    }

    /// 强制立即更新
    func forceUpdate(_ page: Int) {
        updateTask?.cancel()
        actualPage = page
        applyUpdate()
    }

    private func applyUpdate() {
        displayPage = actualPage
        lastUpdateTime = DispatchTime.now().uptimeNanoseconds
        isRapidPaging = false
    }

    private func scheduleUpdate() {
        updateTask?.cancel()

        updateTask = Task { [weak self] in
            guard let self = self else { return }

            try? await Task.sleep(nanoseconds: UInt64(self.intervalMs) * 1_000_000)

            guard !Task.isCancelled else { return }

            self.applyUpdate()
            self.updateTask = nil
        }
    }

    deinit {
        updateTask?.cancel()
    }
}
