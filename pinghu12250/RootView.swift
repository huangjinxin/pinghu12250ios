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

    @State private var showSplash = true
    @State private var bannerText: String?

    var body: some View {
        ZStack(alignment: .top) {
            if !showSplash {
                mainContent
                    .transition(.opacity.animation(.easeInOut(duration: 0.4)))
            }

            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(100)
            }

            if let bannerText, !showSplash {
                Text(bannerText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(12)
                    .padding(.top, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(200)
            }
        }
        .dynamicTypeSize(appSettings.dynamicTypeSize)
        .task {
            await performStartupSanityCheck()
        }
        .onReceive(NotificationCenter.default.publisher(for: .imIncomingBanner)) { notification in
            guard let sender = notification.userInfo?["sender"] as? String,
                  let content = notification.userInfo?["content"] as? String else { return }
            withAnimation {
                bannerText = "\(sender)：\(content)"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    bannerText = nil
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .stateSanityNavigationReset)) { _ in
            appLog("[RootView] 收到导航重置通知")
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            Group {
                if authManager.isAuthenticated {
                    if authManager.currentUser?.role == .parent {
                        ParentTabView()
                    } else {
                        SidebarNavigationView()
                    }
                } else {
                    LoginView()
                }
            }
            .speakable()
            .animation(.easeInOut, value: authManager.isAuthenticated)
            .opacity(showRecoveryUI ? 0.3 : 1.0)
            .disabled(showRecoveryUI)

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

    @MainActor
    private func performStartupSanityCheck() async {
        guard !hasCheckedSanity else { return }
        hasCheckedSanity = true

        sanityResult = StateSanityChecker.shared.performStartupCheck()

        if sanityResult.needsRecovery {
            appLog("[RootView] 需要恢复: \(sanityResult)")
            await Task { @MainActor in
                StateSanityChecker.shared.performStateCleanup()
            }.value

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
