//
//  AITeacherListView.swift
//  pinghu12250
//
//  AI 老师列表页（右侧详情区）
//

import SwiftUI

struct AITeacherListView: View {
    @StateObject private var vm = ChatViewModel()

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("AI 老师")
                    .font(.system(size: 22, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            if vm.bots.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                    Text("正在加载 AI 老师")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(vm.bots) { bot in
                            Button {
                                IMNavigationHelper.openBotChat(botId: bot.id)
                            } label: {
                                aiTeacherCard(bot: bot)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .task {
            await vm.loadAll()
        }
    }

    private func aiTeacherCard(bot: Bot) -> some View {
        VStack(spacing: 12) {
            BotAvatarView(avatar: bot.avatar, name: bot.name, size: 64)

            Text(bot.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            Text(bot.description ?? bot.welcome ?? "点击开始对话")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}
