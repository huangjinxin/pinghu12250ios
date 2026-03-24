//
//  NewProfileView.swift
//  pinghu12250
//
//  我的页面
//

import SwiftUI

struct NewProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showWallet = false
    @State private var showPoints = false

    var body: some View {
        List {
            Section {
                ProfileHeaderView()
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            Section("财务管理") {
                Button {
                    showWallet = true
                } label: {
                    ProfileMenuItem(icon: "creditcard.fill", title: "我的钱包", color: .green)
                }

                Button {
                    showPoints = true
                } label: {
                    ProfileMenuItem(icon: "star.fill", title: "我的积分", color: .orange)
                }
            }

            Section("学习内容") {
                ProfileMenuItem(icon: "book.fill", title: "我的教材", color: .appPrimary)
                ProfileMenuItem(icon: "pencil", title: "我的作业", color: .appWarning)
                ProfileMenuItem(icon: "note.text", title: "我的笔记", color: .appSuccess)
                ProfileMenuItem(icon: "paintbrush.fill", title: "我的作品", color: .appAccent)
                ProfileMenuItem(icon: "chart.bar.fill", title: "学习统计", color: .appInfo)
            }

            Section {
                ProfileMenuItem(icon: "gearshape.fill", title: "设置", color: .gray)
            }
        }
        .navigationTitle("我的")
        .sheet(isPresented: $showWallet) {
            NavigationStack {
                WalletView()
            }
        }
        .sheet(isPresented: $showPoints) {
            NavigationStack {
                PointsView()
            }
        }
    }
}

struct ProfileHeaderView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Circle()
                .fill(Color.appPrimary.opacity(0.15))
                .frame(width: Theme.AvatarSize.xlarge, height: Theme.AvatarSize.xlarge)
                .overlay(
                    Text(authManager.currentUser?.avatarLetter ?? "我")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.appPrimary)
                )

            VStack(spacing: 4) {
                Text(authManager.currentUser?.nickname ?? "用户")
                    .font(.system(size: Theme.FontSize.title, weight: .bold))
                Text("五年级1班")
                    .font(.system(size: Theme.FontSize.body))
                    .foregroundColor(.messageSecondaryText)
            }

            HStack(spacing: Theme.Spacing.xl) {
                ProfileStatItem(value: "1250", label: "积分")
                Divider().frame(height: 30)
                ProfileStatItem(value: "45", label: "学习天数")
                Divider().frame(height: 30)
                ProfileStatItem(value: "12", label: "获得奖励")
            }
        }
        .padding(.vertical, Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
    }
}

private struct ProfileStatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.appPrimary)
            Text(label)
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.messageSecondaryText)
        }
    }
}

private struct ProfileMenuItem: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 28)

            Text(title)
                .font(.system(size: Theme.FontSize.body))

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.messageSecondaryText)
        }
    }
}
