//
//  StateSanityChecker.swift
//  pinghu12250
//
//  启动阶段状态清洗 - 检测并恢复坏状态
//  解决 Fatal Error 导致的"假死"问题：
//  - App 状态被系统保留
//  - 上滑杀进程无效
//  - 再次进入仍停留在坏状态
//

import Foundation
import SwiftUI

// MARK: - StateSanityChecker

/// 启动阶段状态清洗器
/// 在 App 启动时检查上次会话是否发生了致命错误
/// 如果发现坏状态标记，自动清空相关状态并回到安全首页
final class StateSanityChecker {
    static let shared = StateSanityChecker()

    private let userDefaults = UserDefaults.standard
    private let stateKey = "app_state_sanity"
    private let fatalStateKey = "fatal_ui_state"
    private let lastScreenKey = "last_active_screen"
    private let crashCountKey = "consecutive_crash_count"

    private init() {}

    // MARK: - 状态标记

    /// 标记进入可能崩溃的危险区域
    func markDangerousEntry(screen: String, context: String = "") {
        userDefaults.set(screen, forKey: lastScreenKey)
        userDefaults.set(true, forKey: fatalStateKey)
        userDefaults.set(context, forKey: "last_danger_context")
        userDefaults.set(Date().timeIntervalSince1970, forKey: "last_danger_timestamp")
        userDefaults.synchronize()

        appLog("[StateSanity] 进入危险区域: \(screen) - \(context)")
    }

    /// 标记安全退出危险区域
    func markSafeExit() {
        userDefaults.set(false, forKey: fatalStateKey)
        userDefaults.removeObject(forKey: "last_danger_context")
        userDefaults.synchronize()

        appLog("[StateSanity] 安全退出危险区域")
    }

    /// 标记发生了致命 UI 状态错误
    func markFatalUIState(reason: String) {
        userDefaults.set(true, forKey: fatalStateKey)
        userDefaults.set(reason, forKey: "fatal_reason")
        userDefaults.synchronize()

        // 增加连续崩溃计数
        let count = userDefaults.integer(forKey: crashCountKey)
        userDefaults.set(count + 1, forKey: crashCountKey)

        appLog("[StateSanity] 标记致命状态: \(reason), 连续崩溃次数: \(count + 1)")

        // 保存快照
        let snapshot = FreezeSnapshot.capture(
            reason: "FatalUIState: \(reason)",
            level: .level3_resetState,
            currentScreen: userDefaults.string(forKey: lastScreenKey)
        )
        FreezeSnapshotStorage.shared.save(snapshot)
    }

    // MARK: - 启动检查

    /// 执行启动阶段状态检查
    /// - Returns: 是否需要重置到安全首页
    @MainActor
    func performStartupCheck() -> StateSanityResult {
        let wasFatal = userDefaults.bool(forKey: fatalStateKey)
        let lastScreen = userDefaults.string(forKey: lastScreenKey) ?? "Unknown"
        let fatalReason = userDefaults.string(forKey: "fatal_reason") ?? ""
        let crashCount = userDefaults.integer(forKey: crashCountKey)

        // 检查上次是否在危险区域崩溃
        if wasFatal {
            appLog("[StateSanity] 检测到上次致命状态: \(lastScreen) - \(fatalReason)")

            // 记录诊断
            let snapshot = FreezeSnapshot.capture(
                reason: "Startup recovery from fatal state: \(fatalReason)",
                level: .level3_resetState,
                currentScreen: lastScreen
            )
            FreezeSnapshotStorage.shared.save(snapshot)

            // 清除标记
            clearFatalState()

            // 如果连续崩溃次数过多，建议重置
            if crashCount >= 3 {
                appLog("[StateSanity] 连续崩溃 \(crashCount) 次，建议完全重置")
                return .requireFullReset(
                    reason: "连续崩溃 \(crashCount) 次",
                    lastScreen: lastScreen
                )
            }

            return .requireRecovery(
                reason: fatalReason,
                lastScreen: lastScreen,
                consecutiveCrashes: crashCount
            )
        }

        // 重置连续崩溃计数（正常启动）
        userDefaults.set(0, forKey: crashCountKey)

        return .healthy
    }

    /// 清除致命状态标记
    func clearFatalState() {
        userDefaults.set(false, forKey: fatalStateKey)
        userDefaults.removeObject(forKey: "fatal_reason")
        userDefaults.removeObject(forKey: lastScreenKey)
        userDefaults.removeObject(forKey: "last_danger_context")
        userDefaults.synchronize()
    }

    /// 清除连续崩溃计数
    func clearCrashCount() {
        userDefaults.set(0, forKey: crashCountKey)
    }

    // MARK: - 状态清洗

    /// 执行状态清洗
    @MainActor
    func performStateCleanup() {
        appLog("[StateSanity] 执行状态清洗...")

        // 1. 清除 ViewScope 和 ScreenScope 相关的持久化状态
        clearPersistedScopeState()

        // 2. 清除可能导致崩溃的缓存
        clearDangerousCache()

        // 3. 重置导航状态
        resetNavigationState()

        // 4. 清除 SliderDiagnostics 和 RangeGuardDiagnostics
        SliderDiagnostics.shared.clear()
        RangeGuardDiagnostics.shared.clear()

        appLog("[StateSanity] 状态清洗完成")
    }

    private func clearPersistedScopeState() {
        // 清除可能存储的 scope 状态
        let scopeKeys = userDefaults.dictionaryRepresentation().keys.filter {
            $0.hasPrefix("scope_") || $0.hasPrefix("screen_") || $0.hasPrefix("view_")
        }

        for key in scopeKeys {
            userDefaults.removeObject(forKey: key)
        }
    }

    private func clearDangerousCache() {
        // 清除 PDF 缓存
        Task { @MainActor in
            PDFPageCache.shared.clearCache()
        }

        // 清除聊天图片缓存
        ChatImageStorage.shared.deleteAll()
    }

    private func resetNavigationState() {
        // 发送导航重置通知
        NotificationCenter.default.post(name: .stateSanityNavigationReset, object: nil)
    }
}

// MARK: - StateSanityResult

/// 状态检查结果
enum StateSanityResult {
    /// 状态健康，无需处理
    case healthy

    /// 需要恢复（清洗状态后可继续）
    case requireRecovery(reason: String, lastScreen: String, consecutiveCrashes: Int)

    /// 需要完全重置（连续崩溃过多）
    case requireFullReset(reason: String, lastScreen: String)

    var isHealthy: Bool {
        if case .healthy = self { return true }
        return false
    }

    var needsRecovery: Bool {
        switch self {
        case .healthy: return false
        case .requireRecovery, .requireFullReset: return true
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let stateSanityNavigationReset = Notification.Name("stateSanityNavigationReset")
    static let stateSanityRecoveryCompleted = Notification.Name("stateSanityRecoveryCompleted")
}

// MARK: - View Modifier

/// 危险区域标记修饰器
struct DangerousAreaModifier: ViewModifier {
    let screenName: String
    let context: String

    func body(content: Content) -> some View {
        content
            .onAppear {
                StateSanityChecker.shared.markDangerousEntry(screen: screenName, context: context)
            }
            .onDisappear {
                StateSanityChecker.shared.markSafeExit()
            }
    }
}

extension View {
    /// 标记 View 为危险区域（可能导致崩溃的区域）
    func markDangerousArea(screen: String, context: String = "") -> some View {
        modifier(DangerousAreaModifier(screenName: screen, context: context))
    }
}

// MARK: - 启动恢复视图

/// 启动恢复提示视图
struct StartupRecoveryView: View {
    let result: StateSanityResult
    let onContinue: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            VStack(spacing: 8) {
                Text("应用需要恢复")
                    .font(.title2)
                    .fontWeight(.semibold)

                if case .requireRecovery(let reason, let lastScreen, let crashes) = result {
                    Text("上次在「\(lastScreen)」遇到问题")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if !reason.isEmpty {
                        Text(reason)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if crashes > 1 {
                        Text("已连续发生 \(crashes) 次")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                if case .requireFullReset(let reason, _) = result {
                    Text(reason)
                        .font(.subheadline)
                        .foregroundColor(.red)

                    Text("建议完全重置应用状态")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 12) {
                Button(action: {
                    StateSanityChecker.shared.performStateCleanup()
                    onContinue()
                }) {
                    Text("清理并继续")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                if case .requireFullReset = result {
                    Button(action: {
                        StateSanityChecker.shared.performStateCleanup()
                        StateSanityChecker.shared.clearCrashCount()
                        onReset()
                    }) {
                        Text("完全重置")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(10)
                    }
                }

                Button(action: onContinue) {
                    Text("忽略并继续")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Cold Safe Root

/// 冷启动安全根视图
/// 在检测到坏状态时显示此视图，防止进入崩溃循环
struct ColdSafeRootView<Content: View>: View {
    @State private var sanityResult: StateSanityResult = .healthy
    @State private var isRecovering = true
    @State private var showRecoveryUI = false

    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ZStack {
            if isRecovering && showRecoveryUI {
                StartupRecoveryView(
                    result: sanityResult,
                    onContinue: {
                        withAnimation {
                            isRecovering = false
                        }
                    },
                    onReset: {
                        withAnimation {
                            isRecovering = false
                        }
                    }
                )
            } else {
                content()
            }
        }
        .task {
            await performStartupCheck()
        }
    }

    @MainActor
    private func performStartupCheck() async {
        sanityResult = StateSanityChecker.shared.performStartupCheck()

        if sanityResult.needsRecovery {
            showRecoveryUI = true
        } else {
            isRecovering = false
        }
    }
}
