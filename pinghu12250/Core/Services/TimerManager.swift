//
//  TimerManager.swift
//  pinghu12250
//
//  统一 Timer 管理器 - 防止 Timer 泄漏
//  所有 Timer 通过此管理器创建，自动管理生命周期
//

import Foundation
import Combine

// MARK: - Timer 管理器

@MainActor
final class TimerManager {
    static let shared = TimerManager()

    // 存储活跃的 Timer 订阅
    private var timers: [String: AnyCancellable] = [:]
    // 存储 Timer 的创建时间（用于调试）
    private var timerInfo: [String: Date] = [:]

    private init() {}

    // MARK: - 注册 Timer

    /// 注册一个重复执行的 Timer
    /// - Parameters:
    ///   - id: Timer 的唯一标识符
    ///   - interval: 执行间隔（秒）
    ///   - tolerance: 允许的误差（秒），默认为间隔的 10%
    ///   - action: 每次触发时执行的操作
    /// - Returns: 可用于手动取消的 AnyCancellable（通常不需要保留）
    @discardableResult
    func register(
        id: String,
        interval: TimeInterval,
        tolerance: TimeInterval? = nil,
        action: @escaping () -> Void
    ) -> AnyCancellable {
        // 先取消已有的同 ID Timer
        invalidate(id: id)

        let actualTolerance = tolerance ?? (interval * 0.1)

        let cancellable = Timer.publish(every: interval, tolerance: actualTolerance, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                // 检查 Timer 是否仍然有效
                guard self?.timers[id] != nil else { return }
                action()
            }

        timers[id] = cancellable
        timerInfo[id] = Date()

        return cancellable
    }

    /// 注册一个延迟执行的一次性 Timer
    /// - Parameters:
    ///   - id: Timer 的唯一标识符
    ///   - delay: 延迟时间（秒）
    ///   - action: 执行的操作
    func scheduleOnce(
        id: String,
        delay: TimeInterval,
        action: @escaping () -> Void
    ) {
        // 先取消已有的同 ID Timer
        invalidate(id: id)

        let cancellable = Timer.publish(every: delay, on: .main, in: .common)
            .autoconnect()
            .first()
            .sink { [weak self] _ in
                action()
                self?.invalidate(id: id)
            }

        timers[id] = cancellable
        timerInfo[id] = Date()
    }

    // MARK: - 取消 Timer

    /// 取消指定 ID 的 Timer
    func invalidate(id: String) {
        timers[id]?.cancel()
        timers.removeValue(forKey: id)
        timerInfo.removeValue(forKey: id)
    }

    /// 取消所有以指定前缀开头的 Timer
    /// 用于按模块批量清理，例如 invalidateAll(prefix: "practice_")
    func invalidateAll(prefix: String) {
        let keysToRemove = timers.keys.filter { $0.hasPrefix(prefix) }
        for key in keysToRemove {
            invalidate(id: key)
        }
    }

    /// 取消所有 Timer
    func invalidateAll() {
        for key in timers.keys {
            timers[key]?.cancel()
        }
        timers.removeAll()
        timerInfo.removeAll()
    }

    // MARK: - 状态查询

    /// 检查指定 ID 的 Timer 是否存在
    func isActive(id: String) -> Bool {
        return timers[id] != nil
    }

    /// 获取当前活跃的 Timer 数量
    var activeCount: Int {
        timers.count
    }

    /// 获取所有活跃的 Timer ID（用于调试）
    var activeTimerIds: [String] {
        Array(timers.keys)
    }

    /// 获取 Timer 信息（用于调试）
    func getTimerInfo() -> [(id: String, createdAt: Date)] {
        timerInfo.map { (id: $0.key, createdAt: $0.value) }
            .sorted { $0.createdAt < $1.createdAt }
    }
}

// MARK: - SwiftUI View 扩展

import SwiftUI

extension View {
    /// 在 View 生命周期内自动管理 Timer
    /// Timer 会在 View 消失时自动取消
    func withTimer(
        id: String,
        interval: TimeInterval,
        action: @escaping () -> Void
    ) -> some View {
        self
            .onAppear {
                TimerManager.shared.register(id: id, interval: interval, action: action)
            }
            .onDisappear {
                TimerManager.shared.invalidate(id: id)
            }
    }

    /// 在 View 生命周期内延迟执行一次
    func withDelayedAction(
        id: String,
        delay: TimeInterval,
        action: @escaping () -> Void
    ) -> some View {
        self
            .onAppear {
                TimerManager.shared.scheduleOnce(id: id, delay: delay, action: action)
            }
            .onDisappear {
                TimerManager.shared.invalidate(id: id)
            }
    }
}

// MARK: - 常用 Timer ID 前缀

extension TimerManager {
    /// Timer ID 命名规范
    enum TimerPrefix {
        /// 加载动画相关
        static let loading = "loading_"
        /// 练习相关
        static let practice = "practice_"
        /// 录音相关
        static let recording = "recording_"
        /// 刷新相关
        static let refresh = "refresh_"
        /// 动画相关
        static let animation = "animation_"
    }
}
