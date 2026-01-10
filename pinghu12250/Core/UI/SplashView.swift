//
//  SplashView.swift
//  pinghu12250
//
//  启动动画视图 - 用于解决App启动白屏问题
//  纯展示组件，不包含业务逻辑
//

import SwiftUI

struct SplashView: View {
    // 动画状态
    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.92
    @State private var subtitleOpacity: Double = 0
    @State private var showLoadingDots = false

    // 完成回调
    let onFinished: () -> Void

    // 动画配置
    private let animationDuration: Double = 2.5
    private let minimumDisplayTime: Double = 2.0

    var body: some View {
        ZStack {
            // 背景 - 渐变色
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.98, green: 0.98, blue: 1.0),
                    Color(red: 0.95, green: 0.96, blue: 0.99)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Logo 区域
                VStack(spacing: 16) {
                    // App 图标
                    ZStack {
                        // 外层光晕
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        Color.appPrimary.opacity(0.15),
                                        Color.appPrimary.opacity(0)
                                    ]),
                                    center: .center,
                                    startRadius: 60,
                                    endRadius: 120
                                )
                            )
                            .frame(width: 220, height: 220)

                        // 主图标背景
                        RoundedRectangle(cornerRadius: 36)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.4, green: 0.6, blue: 0.95),
                                        Color(red: 0.55, green: 0.45, blue: 0.90)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 140, height: 140)
                            .shadow(color: Color.appPrimary.opacity(0.3), radius: 25, x: 0, y: 12)

                        // 图标
                        Image(systemName: "book.fill")
                            .font(.system(size: 60, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                    // App 名称
                    VStack(spacing: 8) {
                        Text("苹湖少儿空间")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.3, green: 0.35, blue: 0.5),
                                        Color(red: 0.45, green: 0.45, blue: 0.65)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        Text("Study Workspace")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.8))
                            .opacity(subtitleOpacity)
                    }
                    .opacity(logoOpacity)
                }

                Spacer()

                // 底部加载指示
                VStack(spacing: 12) {
                    if showLoadingDots {
                        LoadingDotsView()
                            .transition(.opacity)
                    }

                    Text("正在准备学习环境...")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.6))
                        .opacity(subtitleOpacity)
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Logo 淡入 + 放大动画（更慢）
        withAnimation(.easeOut(duration: 1.2)) {
            logoOpacity = 1.0
            logoScale = 1.0
        }

        // 副标题延迟淡入
        withAnimation(.easeOut(duration: 0.8).delay(0.6)) {
            subtitleOpacity = 1.0
        }

        // 加载点延迟显示
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeIn(duration: 0.4)) {
                showLoadingDots = true
            }
        }

        // 确保至少显示 minimumDisplayTime 秒后回调
        DispatchQueue.main.asyncAfter(deadline: .now() + minimumDisplayTime) {
            onFinished()
        }
    }
}

// MARK: - 加载点动画

struct LoadingDotsView: View {
    @State private var animatingDots = [false, false, false]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.appPrimary.opacity(animatingDots[index] ? 0.8 : 0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(animatingDots[index] ? 1.2 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15),
                        value: animatingDots[index]
                    )
            }
        }
        .onAppear {
            // 启动动画
            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                    animatingDots[i] = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SplashView {
        #if DEBUG
        print("Splash finished")
        #endif
    }
}
