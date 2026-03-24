//
//  ConversationListSidebarView.swift
//  pinghu12250
//
//  横屏侧边栏会话列表
//

import SwiftUI

struct ConversationListSidebarView: View {
    @StateObject private var conversationStore = IMConversationStore.shared
    @EnvironmentObject var authManager: AuthManager
    @Binding var botSelection: Bot?
    @Binding var pendingBotId: String?
    @State private var showSettings = false

    var body: some View {
        List {
            if !conversationStore.conversations.isEmpty {
                Section("联系人消息") {
                    ForEach(conversationStore.conversations) { conversation in
                        Button {
                            botSelection = nil
                            conversationStore.selectConversation(conversation)
                        } label: {
                            IMConversationRow(
                                conversation: conversation,
                                isSelected: isSelectedIM(conversation)
                            )
                        }
                        .listRowBackground(
                            isSelectedIM(conversation) ? Color.appPrimary.opacity(0.15) : Color.white
                        )
                        .listRowSeparator(.visible, edges: .bottom)
                        .listRowSeparatorTint(Color.messageBorder)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                }
            }
        }
        .listStyle(.plain)
        .background(Color.white)
        .refreshable {
            await conversationStore.loadConversations()
        }
        .task {
            applyPendingBotId()
            await conversationStore.loadConversations()
        }
        .onChange(of: pendingBotId) { _, newValue in
            if newValue != nil {
                applyPendingBotId()
            }
        }
        .navigationTitle("消息")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showSettings = true } label: {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(authManager.currentUser?.avatarLetter ?? "我")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.blue)
                        )
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SystemSettingsView()
                .environmentObject(authManager)
        }
    }

    private func applyPendingBotId() {
        guard pendingBotId != nil else { return }
        conversationStore.clearSelection()
        pendingBotId = nil
    }

    private func isSelectedIM(_ conversation: IMConversation) -> Bool {
        if botSelection != nil { return false }
        return conversationStore.selectedConversationId == conversation.id
    }
}

private struct IMConversationRow: View {
    let conversation: IMConversation
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: avatarURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Text(String(conversation.name.prefix(1)))
                            .foregroundColor(.white)
                    )
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.name)
                        .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(.messagePrimaryText)
                    Spacer()
                    if let time = conversation.lastMessageTime {
                        Text(formatTime(time))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    Text(conversation.lastMessage ?? "")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var avatarURL: URL? {
        guard let avatar = conversation.avatar else { return nil }
        if avatar.hasPrefix("http") {
            return URL(string: avatar)
        }
        return URL(string: APIConfig.baseURL + avatar)
    }

    private func formatTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return "" }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            return timeFormatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM/dd"
            return dateFormatter.string(from: date)
        }
    }
}
