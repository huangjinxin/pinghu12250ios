//
//  pinghu12250App.swift
//  pinghu12250
//
//  苹湖少儿空间 - iPad App
//  稳定性专项：集成三级看门狗、内存水位监控、诊断系统
//

import SwiftUI
import UIKit

// MARK: - AppDelegate（支持后台下载）

class AppDelegate: NSObject, UIApplicationDelegate {
    var backgroundCompletionHandler: (() -> Void)?

    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        // 保存完成处理器，供 DownloadManager 调用
        backgroundCompletionHandler = completionHandler

        // 监听下载管理器完成事件
        NotificationCenter.default.addObserver(
            forName: .downloadManagerDidFinishBackgroundEvents,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.backgroundCompletionHandler?()
            self?.backgroundCompletionHandler = nil
        }
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // 初始化日志系统
        appLog("应用启动")
        log.info("应用启动")

        // 检查上次会话的冻结快照
        checkPreviousSessionSnapshots()

        // 初始化下载管理器（确保后台任务能被恢复）
        _ = DownloadManager.shared

        // 初始化内存管理器并启动监控
        Task { @MainActor in
            MemoryManager.shared.startMonitoring()
        }

        // 启动三级看门狗
        MainThreadWatchdog.shared.integrateWithApp()

        appLog("核心稳定性服务初始化完成")
        log.info("核心服务初始化完成")

        return true
    }

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        appLog("收到系统内存警告")
        log.warning("收到系统内存警告")
        Task { @MainActor in
            MemoryManager.shared.handleMemoryWarning()
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        appLog("应用即将终止")
        log.info("应用即将终止")

        // 停止看门狗
        MainThreadWatchdog.shared.stop()

        // 停止内存监控
        Task { @MainActor in
            MemoryManager.shared.stopMonitoring()
        }

        // 取消所有请求
        Task { @MainActor in
            RequestController.shared.cancelAll()
        }
    }

    // MARK: - 诊断

    /// 检查上次会话的冻结快照
    private func checkPreviousSessionSnapshots() {
        let snapshots = FreezeSnapshotStorage.shared.loadLastSessionSnapshots()

        if !snapshots.isEmpty {
            appLog("发现 \(snapshots.count) 个上次会话的冻结快照")

            // 如果有 Level 3 的快照，说明上次可能发生了严重卡顿
            let level3Snapshots = snapshots.filter { $0.level == .level3_resetState }
            if !level3Snapshots.isEmpty {
                appLog("上次会话发生过 \(level3Snapshots.count) 次严重卡顿")
                // 标记致命状态，供 StateSanityChecker 处理
                for snapshot in level3Snapshots {
                    if snapshot.reason.contains("Fatal") || snapshot.reason.contains("fatal") {
                        StateSanityChecker.shared.markFatalUIState(reason: snapshot.reason)
                        break
                    }
                }
            }
        }

        // 检查 JSON 解码失败记录
        let jsonFailures = JSONDecodeFailureStorage.shared.loadAll()
        if !jsonFailures.isEmpty {
            appLog("发现 \(jsonFailures.count) 个 JSON 解码失败记录")
        }
    }
}

// MARK: - Main App

@main
struct pinghu12250App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var memoryManager = MemoryManager.shared
    @StateObject private var appSettings = AppSettings.shared

    init() {
        // 配置日志级别
        #if DEBUG
        Logger.shared.minLevel = .debug
        #else
        Logger.shared.minLevel = .info
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(memoryManager)
                .preferredColorScheme(appSettings.themeMode.colorScheme)
                // 三级看门狗恢复处理
                .onReceive(NotificationCenter.default.publisher(for: .watchdogLevel1)) { notification in
                    if let snapshot = notification.userInfo?["snapshot"] as? FreezeSnapshot {
                        appLog("Watchdog Level1: \(snapshot.reason)")
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .watchdogLevel2)) { _ in
                    appLog("Watchdog Level2: 已取消所有任务")
                    log.warning("看门狗 Level2 触发")
                }
                .onReceive(NotificationCenter.default.publisher(for: .watchdogLevel3)) { notification in
                    appLog("Watchdog Level3: 执行状态重置")
                    log.error("看门狗 Level3 触发 - 严重阻塞")
                    // 可以在这里触发全局状态重置
                }
                // 兼容旧版通知
                .onReceive(NotificationCenter.default.publisher(for: .watchdogRecovery)) { _ in
                    log.warning("看门狗触发恢复")
                }
                // 内存降级提示
                .onReceive(NotificationCenter.default.publisher(for: .memoryLevel90)) { _ in
                    appLog("内存紧急：执行强制清理")
                    // 可以在这里显示用户提示
                }
        }
    }
}
