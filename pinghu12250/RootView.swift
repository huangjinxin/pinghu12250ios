//
//  RootView.swift
//  pinghu12250
//
//  根视图 - 根据认证状态显示不同界面
//  集成启动动画和状态清洗机制
//

import SwiftUI
import Combine

struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var appSettings = AppSettings.shared
    @State private var sanityResult: StateSanityResult = .healthy
    @State private var hasCheckedSanity = false
    @State private var showRecoveryUI = false

    // 启动动画状态
    @State private var showSplash = true

    var body: some View {
        ZStack {
            // 主内容（启动动画结束后显示）
            if !showSplash {
                mainContent
                    .transition(.opacity.animation(.easeInOut(duration: 0.4)))
            }

            // 启动动画（最上层）
            if showSplash {
                SplashView {
                    // 动画完成后切换到主界面
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        // 应用字体大小设置
        .dynamicTypeSize(appSettings.dynamicTypeSize)
        .task {
            // 启动动画期间可以执行初始化检查
            await performStartupSanityCheck()
        }
        // 监听导航重置通知
        .onReceive(NotificationCenter.default.publisher(for: .stateSanityNavigationReset)) { _ in
            appLog("[RootView] 收到导航重置通知")
        }
    }

    // MARK: - 主内容视图

    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            // 主内容
            Group {
                if authManager.isAuthenticated {
                    // 根据角色显示不同界面
                    if authManager.currentUser?.role == .parent {
                        ParentTabView()
                    } else {
                        MainTabView()
                    }
                } else {
                    LoginView()
                }
            }
            .speakable()  // 启用全局文本选择（配合系统朗读功能）
            .animation(.easeInOut, value: authManager.isAuthenticated)
            .opacity(showRecoveryUI ? 0.3 : 1.0)
            .disabled(showRecoveryUI)

            // 恢复 UI 覆盖层
            if showRecoveryUI {
                StartupRecoveryView(
                    result: sanityResult,
                    onContinue: {
                        withAnimation {
                            showRecoveryUI = false
                        }
                        NotificationCenter.default.post(name: .stateSanityRecoveryCompleted, object: nil)
                    },
                    onReset: {
                        // 完全重置：登出并清理
                        Task { @MainActor in
                            authManager.logout()
                        }
                        withAnimation {
                            showRecoveryUI = false
                        }
                        NotificationCenter.default.post(name: .stateSanityRecoveryCompleted, object: nil)
                    }
                )
                .transition(.opacity.combined(with: .scale))
            }
        }
    }

    // MARK: - 启动检查

    @MainActor
    private func performStartupSanityCheck() async {
        guard !hasCheckedSanity else { return }
        hasCheckedSanity = true

        sanityResult = StateSanityChecker.shared.performStartupCheck()

        if sanityResult.needsRecovery {
            appLog("[RootView] 需要恢复: \(sanityResult)")
            // 先执行清洗
            await Task { @MainActor in
                StateSanityChecker.shared.performStateCleanup()
            }.value

            // 等待启动动画结束后再显示恢复 UI
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if !showSplash {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showRecoveryUI = true
                    }
                }
            }
        } else {
            appLog("[RootView] 状态健康")
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AuthManager.shared)
}
