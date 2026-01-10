//
//  MainThreadWatchdog.swift
//  pinghu12250
//
//  主线程看门狗 - 检测主线程阻塞并执行三级恢复策略
//
//  三级恢复策略：
//  Level 1 (>2s): 记录 FreezeSnapshot（日志、活跃 Task、内存）
//  Level 2 (>3s): cancel 所有活跃 TaskBag + 清空 RequestController 队列
//  Level 3 (>4s): 重置 Reader/AI 会话状态 + 安全回退到可交互页面
//

import Foundation
import UIKit
import Combine

// MARK: - 恢复级别

enum WatchdogRecoveryLevel: Int, Comparable {
    case none = 0
    case level1_snapshot = 1      // >2s: 记录快照
    case level2_cancelTasks = 2   // >3s: 取消任务
    case level3_resetState = 3    // >4s: 重置状态

    static func < (lhs: WatchdogRecoveryLevel, rhs: WatchdogRecoveryLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var threshold: TimeInterval {
        switch self {
        case .none: return 0
        case .level1_snapshot: return 2.0
        case .level2_cancelTasks: return 3.0
        case .level3_resetState: return 4.0
        }
    }

    var description: String {
        switch self {
        case .none: return "正常"
        case .level1_snapshot: return "Level1-记录快照"
        case .level2_cancelTasks: return "Level2-取消任务"
        case .level3_resetState: return "Level3-重置状态"
        }
    }
}

// MARK: - 主线程看门狗

final class MainThreadWatchdog {
    static let shared = MainThreadWatchdog()

    // 检测间隔（秒）
    private let checkInterval: TimeInterval = 0.5

    // 看门狗定时器
    private var watchdogTimer: DispatchSourceTimer?

    // 主线程响应标记
    private var mainThreadResponded = true

    // 上次响应时间
    private var lastResponseTime: Date = Date()

    // 当前已执行的恢复级别（防止重复执行）
    private var currentRecoveryLevel: WatchdogRecoveryLevel = .none

    // 是否已启动
    private(set) var isRunning = false

    // 统计数据
    private(set) var level1Count = 0
    private(set) var level2Count = 0
    private(set) var level3Count = 0

    // 回调
    var onLevel1: ((FreezeSnapshot) -> Void)?
    var onLevel2: (() -> Void)?
    var onLevel3: (() -> Void)?

    private init() {}

    // MARK: - 启动/停止

    /// 启动看门狗
    func start() {
        guard !isRunning else { return }

        isRunning = true
        mainThreadResponded = true
        lastResponseTime = Date()
        currentRecoveryLevel = .none

        // 创建后台定时器
        let queue = DispatchQueue(label: "com.pinghu12250.watchdog", qos: .userInteractive)
        watchdogTimer = DispatchSource.makeTimerSource(queue: queue)
        watchdogTimer?.schedule(deadline: .now() + checkInterval, repeating: checkInterval)

        watchdogTimer?.setEventHandler { [weak self] in
            self?.checkMainThread()
        }

        watchdogTimer?.resume()

        #if DEBUG
        print("[Watchdog] 三级看门狗已启动")
        #endif
    }

    /// 停止看门狗
    func stop() {
        isRunning = false
        watchdogTimer?.cancel()
        watchdogTimer = nil
        currentRecoveryLevel = .none
        #if DEBUG
        print("[Watchdog] 看门狗已停止")
        #endif
    }

    // MARK: - 检测逻辑

    private func checkMainThread() {
        // 检查主线程是否响应了上次的 ping
        if !mainThreadResponded {
            let blockDuration = Date().timeIntervalSince(lastResponseTime)

            // 根据阻塞时长决定恢复级别
            let targetLevel = determineRecoveryLevel(duration: blockDuration)

            // 只执行比当前级别更高的恢复操作
            if targetLevel > currentRecoveryLevel {
                executeRecovery(level: targetLevel, duration: blockDuration)
                currentRecoveryLevel = targetLevel
            }
        } else {
            // 主线程响应了，重置恢复级别
            if currentRecoveryLevel != .none {
                #if DEBUG
                print("[Watchdog] 主线程恢复响应，重置恢复级别")
                #endif
                currentRecoveryLevel = .none
            }
        }

        // 发送新的 ping
        mainThreadResponded = false

        DispatchQueue.main.async { [weak self] in
            self?.mainThreadResponded = true
            self?.lastResponseTime = Date()
        }
    }

    private func determineRecoveryLevel(duration: TimeInterval) -> WatchdogRecoveryLevel {
        if duration >= WatchdogRecoveryLevel.level3_resetState.threshold {
            return .level3_resetState
        } else if duration >= WatchdogRecoveryLevel.level2_cancelTasks.threshold {
            return .level2_cancelTasks
        } else if duration >= WatchdogRecoveryLevel.level1_snapshot.threshold {
            return .level1_snapshot
        }
        return .none
    }

    // MARK: - 三级恢复操作

    private func executeRecovery(level: WatchdogRecoveryLevel, duration: TimeInterval) {
        #if DEBUG
        print("[Watchdog] 主线程阻塞 \(String(format: "%.1f", duration))s，执行 \(level.description)")
        #endif

        switch level {
        case .none:
            break

        case .level1_snapshot:
            level1Count += 1
            executeLevel1Recovery(duration: duration)

        case .level2_cancelTasks:
            level2Count += 1
            executeLevel2Recovery(duration: duration)

        case .level3_resetState:
            level3Count += 1
            executeLevel3Recovery(duration: duration)
        }
    }

    /// Level 1: 记录 FreezeSnapshot
    private func executeLevel1Recovery(duration: TimeInterval) {
        // 创建冻结快照
        let snapshot = FreezeSnapshot.capture(
            reason: "主线程阻塞 \(String(format: "%.1f", duration))s",
            level: .level1_snapshot
        )

        // 保存到本地
        FreezeSnapshotStorage.shared.save(snapshot)

        // 回调通知
        onLevel1?(snapshot)

        // 发送通知
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .watchdogLevel1,
                object: nil,
                userInfo: ["snapshot": snapshot]
            )
        }

        #if DEBUG
        print("[Watchdog] Level1 完成: 已记录 FreezeSnapshot")
        #endif
    }

    /// Level 2: 取消所有 Task + 清空请求队列
    private func executeLevel2Recovery(duration: TimeInterval) {
        // 先执行 Level 1（如果尚未执行）
        if currentRecoveryLevel < .level1_snapshot {
            executeLevel1Recovery(duration: duration)
        }

        // 在主线程执行取消操作
        Task { @MainActor in
            // 1. 取消 PDF 渲染任务
            await PDFRenderCoordinator.shared.cancelAll()

            // 2. 清空 RequestController 队列
            RequestController.shared.cancelAll()

            // 3. 清理 PDF 缓存（释放内存）
            PDFPageCache.shared.clearCache()
            LowResPageCache.shared.clearCache()

            // 4. 取消所有 Timer
            TimerManager.shared.invalidateAll()
        }

        // 回调通知
        onLevel2?()

        // 发送通知
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .watchdogLevel2, object: nil)
        }

        #if DEBUG
        print("[Watchdog] Level2 完成: 已取消所有任务和请求")
        #endif
    }

    /// Level 3: 重置状态 + 安全回退
    private func executeLevel3Recovery(duration: TimeInterval) {
        // 先执行 Level 2（如果尚未执行）
        if currentRecoveryLevel < .level2_cancelTasks {
            executeLevel2Recovery(duration: duration)
        }

        // 创建详细快照
        let snapshot = FreezeSnapshot.capture(
            reason: "严重阻塞 \(String(format: "%.1f", duration))s - Level3 恢复",
            level: .level3_resetState
        )
        FreezeSnapshotStorage.shared.save(snapshot)

        // 在主线程执行状态重置
        DispatchQueue.main.async {
            // 发送 Level3 恢复通知（UI 层需要处理）
            NotificationCenter.default.post(
                name: .watchdogLevel3,
                object: nil,
                userInfo: ["snapshot": snapshot]
            )
        }

        // 回调通知
        onLevel3?()

        // 重置响应标记，给主线程恢复机会
        mainThreadResponded = true
        lastResponseTime = Date()

        #if DEBUG
        print("[Watchdog] Level3 完成: 已发送状态重置通知")
        #endif
    }

    // MARK: - 手动触发

    /// 手动触发指定级别的恢复
    func triggerRecovery(level: WatchdogRecoveryLevel) {
        executeRecovery(level: level, duration: level.threshold)
    }

    /// 重置统计
    func resetStats() {
        level1Count = 0
        level2Count = 0
        level3Count = 0
    }

    /// 获取统计摘要
    var statsSummary: String {
        "L1: \(level1Count), L2: \(level2Count), L3: \(level3Count)"
    }
}

// MARK: - 内存水位级别

enum MemoryLevel: Int, Comparable {
    case normal = 0       // <60%
    case level70 = 1      // 70%: 停止预加载
    case level80 = 2      // 80%: 暂停 AI 流式输出
    case level90 = 3      // 90%: 紧急清理

    static func < (lhs: MemoryLevel, rhs: MemoryLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var threshold: Double {
        switch self {
        case .normal: return 0.6
        case .level70: return 0.7
        case .level80: return 0.8
        case .level90: return 0.9
        }
    }

    var description: String {
        switch self {
        case .normal: return "正常"
        case .level70: return "70%-停止预加载"
        case .level80: return "80%-暂停AI输出"
        case .level90: return "90%-紧急清理"
        }
    }
}

// MARK: - 内存管理器（支持主动水位检测）

@MainActor
final class MemoryManager: ObservableObject {
    static let shared = MemoryManager()

    // MARK: - 发布状态

    /// 当前内存水位级别
    @Published private(set) var currentLevel: MemoryLevel = .normal

    /// 是否处于降级模式
    @Published private(set) var isDegraded: Bool = false

    /// 当前内存使用百分比
    @Published private(set) var memoryPercentage: Double = 0

    // MARK: - 配置

    /// 检测间隔（秒）
    private let checkInterval: TimeInterval = 2.0

    /// 恢复阈值（需要降到此比例以下才恢复正常）
    private let recoveryThreshold: Double = 0.6

    // MARK: - 私有属性

    /// 定时检测任务
    private var monitorTask: Task<Void, Never>?

    /// 内存警告次数
    private(set) var warningCount = 0

    /// 上次清理时间
    private var lastCleanupTime: Date?

    /// 最小清理间隔（防止频繁清理）
    private let minCleanupInterval: TimeInterval = 3.0

    /// 是否正在监控
    private(set) var isMonitoring = false

    private init() {
        setupMemoryWarningObserver()
    }

    // MARK: - 启动/停止监控

    /// 启动内存监控
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.checkMemoryLevel()
                try? await Task.sleep(nanoseconds: UInt64(self?.checkInterval ?? 2.0) * 1_000_000_000)
            }
        }

        #if DEBUG
        print("[MemoryManager] 内存监控已启动")
        #endif
    }

    /// 停止内存监控
    func stopMonitoring() {
        isMonitoring = false
        monitorTask?.cancel()
        monitorTask = nil
        #if DEBUG
        print("[MemoryManager] 内存监控已停止")
        #endif
    }

    // MARK: - 内存检测

    private func checkMemoryLevel() {
        let usage = memoryUsage
        memoryPercentage = usage.percentage

        // 确定当前水位级别
        let newLevel = determineLevel(percentage: usage.percentage)

        // 处理级别变化
        if newLevel != currentLevel {
            handleLevelChange(from: currentLevel, to: newLevel)
        }
    }

    private func determineLevel(percentage: Double) -> MemoryLevel {
        if percentage >= MemoryLevel.level90.threshold {
            return .level90
        } else if percentage >= MemoryLevel.level80.threshold {
            return .level80
        } else if percentage >= MemoryLevel.level70.threshold {
            return .level70
        } else if percentage < recoveryThreshold {
            return .normal
        }
        // 在 60%-70% 之间，维持当前状态（防止抖动）
        return currentLevel == .normal ? .normal : currentLevel
    }

    private func handleLevelChange(from oldLevel: MemoryLevel, to newLevel: MemoryLevel) {
        #if DEBUG
        print("[MemoryManager] 内存水位变化: \(oldLevel.description) -> \(newLevel.description)")
        #endif

        currentLevel = newLevel
        isDegraded = newLevel != .normal

        // 执行对应级别的操作
        switch newLevel {
        case .normal:
            handleRecovery()

        case .level70:
            handleLevel70()

        case .level80:
            handleLevel80()

        case .level90:
            handleLevel90()
        }
    }

    // MARK: - 各级别处理

    /// Level 70%: 停止预加载/预渲染
    private func handleLevel70() {
        #if DEBUG
        print("[MemoryManager] Level70: 停止预加载")
        #endif

        // 发送通知
        NotificationCenter.default.post(name: .memoryLevel70, object: nil)

        // 停止 PDF 预加载
        PDFPageCache.shared.setPreloadEnabled(false)
    }

    /// Level 80%: 暂停 AI 流式输出
    private func handleLevel80() {
        #if DEBUG
        print("[MemoryManager] Level80: 暂停 AI 流式输出")
        #endif

        // 先执行 Level 70 的操作
        if currentLevel < .level70 {
            handleLevel70()
        }

        // 发送通知
        NotificationCenter.default.post(name: .memoryLevel80, object: nil)

        // 取消非必要请求
        RequestController.shared.cancelNonEssential()
    }

    /// Level 90%: 紧急清理
    private func handleLevel90() {
        #if DEBUG
        print("[MemoryManager] Level90: 紧急清理")
        #endif
        warningCount += 1

        // 先执行 Level 80 的操作
        if currentLevel < .level80 {
            handleLevel80()
        }

        // 发送通知（UI 层应显示降级提示）
        NotificationCenter.default.post(name: .memoryLevel90, object: nil)

        // 强制清理
        performEmergencyCleanup()
    }

    /// 恢复正常
    private func handleRecovery() {
        #if DEBUG
        print("[MemoryManager] 内存恢复正常")
        #endif

        // 发送恢复通知
        NotificationCenter.default.post(name: .memoryLevelNormal, object: nil)

        // 恢复预加载
        PDFPageCache.shared.setPreloadEnabled(true)
    }

    // MARK: - 清理操作

    /// 紧急清理（Level 90）
    private func performEmergencyCleanup() {
        guard shouldCleanup() else { return }

        lastCleanupTime = Date()

        #if DEBUG
        print("[MemoryManager] 执行紧急清理...")
        #endif

        // 1. 清理 PDF 页面缓存
        PDFPageCache.shared.clearCache()
        LowResPageCache.shared.clearCache()

        // 2. 取消所有后台任务
        Task {
            await PDFRenderCoordinator.shared.cancelAll()
        }

        // 3. 清空 URL 缓存
        URLCache.shared.removeAllCachedResponses()

        // 4. 取消所有网络请求
        RequestController.shared.cancelAll()

        // 5. 取消所有 Timer
        TimerManager.shared.invalidateAll()

        #if DEBUG
        print("[MemoryManager] 紧急清理完成")
        #endif
    }

    /// 检查是否应该执行清理（防止频繁清理）
    private func shouldCleanup() -> Bool {
        if let lastTime = lastCleanupTime {
            return Date().timeIntervalSince(lastTime) >= minCleanupInterval
        }
        return true
    }

    // MARK: - 系统内存警告处理

    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                self?.handleMemoryWarning()
            }
        }
    }

    /// 处理系统内存警告
    func handleMemoryWarning() {
        warningCount += 1
        #if DEBUG
        print("[MemoryManager] 收到系统内存警告 (第 \(warningCount) 次)")
        #endif

        // 直接触发 Level 90 处理
        handleLevel90()
    }

    /// 手动触发清理
    func performCleanup() {
        handleLevel90()
    }

    // MARK: - 内存使用情况

    /// 获取当前内存使用情况
    var memoryUsage: (used: UInt64, total: UInt64, percentage: Double) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let used = info.resident_size
            let total = ProcessInfo.processInfo.physicalMemory
            let percentage = Double(used) / Double(total)
            return (used, total, percentage)
        }

        return (0, ProcessInfo.processInfo.physicalMemory, 0)
    }

    /// 格式化的内存使用情况
    var formattedMemoryUsage: String {
        let usage = memoryUsage
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        let used = formatter.string(fromByteCount: Int64(usage.used))
        let total = formatter.string(fromByteCount: Int64(usage.total))
        let percentage = String(format: "%.1f", usage.percentage * 100)
        return "\(used) / \(total) (\(percentage)%)"
    }

    /// 获取状态摘要
    var statusSummary: String {
        "内存: \(formattedMemoryUsage) | 级别: \(currentLevel.description) | 警告: \(warningCount)次"
    }
}

// MARK: - App 生命周期集成

extension MainThreadWatchdog {
    /// 在 AppDelegate 中调用，集成到应用生命周期
    func integrateWithApp() {
        // 应用进入后台时暂停
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stop()
        }

        // 应用进入前台时恢复
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.start()
        }

        // 启动看门狗
        start()
    }
}
