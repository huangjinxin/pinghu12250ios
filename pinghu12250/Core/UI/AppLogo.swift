//
//  AppLogo.swift
//  pinghu12250
//
//  应用 Logo 组件
//

import SwiftUI

struct AppLogo: View {
    var size: CGFloat = 80
    var showText: Bool = true

    var body: some View {
        VStack(spacing: size * 0.15) {
            // Logo 图标
            ZStack {
                // 背景圆形
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.appPrimary, Color.appPrimary.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)

                // 书本图标
                ZStack {
                    // 翻开的书
                    Image(systemName: "book.fill")
                        .font(.system(size: size * 0.4))
                        .foregroundColor(.white)
                        .offset(x: -size * 0.05, y: size * 0.02)

                    // 苹果装饰
                    Image(systemName: "leaf.fill")
                        .font(.system(size: size * 0.18))
                        .foregroundColor(.white.opacity(0.9))
                        .offset(x: size * 0.2, y: -size * 0.15)
                        .rotationEffect(.degrees(45))
                }
            }
            .shadow(color: Color.appPrimary.opacity(0.3), radius: size * 0.1, y: size * 0.05)

            // 文字
            if showText {
                VStack(spacing: 4) {
                    Text("苹湖")
                        .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("少儿空间")
                        .font(.system(size: size * 0.15, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - 紧凑版 Logo（仅图标）

struct AppLogoCompact: View {
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(
                    LinearGradient(
                        colors: [Color.appPrimary, Color.appPrimary.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            // 苹果 + 书的组合图标
            ZStack {
                Image(systemName: "book.fill")
                    .font(.system(size: size * 0.45, weight: .medium))
                    .foregroundColor(.white)

                Circle()
                    .fill(Color.white)
                    .frame(width: size * 0.2, height: size * 0.2)
                    .offset(x: size * 0.18, y: -size * 0.18)
            }
        }
    }
}

// MARK: - 预览

#Preview("完整 Logo") {
    VStack(spacing: 40) {
        AppLogo(size: 120)
        AppLogo(size: 80)
        AppLogo(size: 60, showText: false)
    }
    .padding()
}

#Preview("紧凑 Logo") {
    HStack(spacing: 20) {
        AppLogoCompact(size: 60)
        AppLogoCompact(size: 40)
        AppLogoCompact(size: 30)
    }
    .padding()
}
