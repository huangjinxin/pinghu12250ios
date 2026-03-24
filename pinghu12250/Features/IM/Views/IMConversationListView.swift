//
//  IMConversationListView.swift
//  pinghu12250
//
//  IM会话列表
//

import SwiftUI

struct IMConversationListView: View {
    @StateObject private var viewModel = IMConversationListViewModel()
    @State private var selectedUserId: String?
    @State private var navigationTrigger = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.conversations) { conversation in
                    NavigationLink(value: conversation) {
                        ConversationRow(conversation: conversation)
                    }
                }
            }
            .navigationTitle("消息")
            .navigationDestination(for: IMConversation.self) { conversation in
                IMChatView(
                    friendUserId: conversation.id,
                    friendName: conversation.name
                )
            }
            .task {
                await viewModel.loadConversations()
            }
            .refreshable {
                await viewModel.loadConversations()
            }
            .onReceive(NotificationCenter.default.publisher(for: .openConversation)) { notification in
                if let userInfo = notification.userInfo,
                   let userId = userInfo["userId"] as? String {
                    selectedUserId = userId
                    Task {
                        await viewModel.loadConversations()
                        if viewModel.conversations.contains(where: { $0.id == userId }) {
                            navigationTrigger = true
                        }
                    }
                }
            }
        }
    }
}

struct ConversationRow: View {
    let conversation: IMConversation

    var body: some View {
        HStack(spacing: 12) {
            // 头像
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
                        .font(.system(size: 16, weight: .semibold))

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
        .padding(.vertical, 4)
    }

    private var avatarURL: URL? {
        guard let avatar = conversation.avatar else { return nil }
        if avatar.hasPrefix("http") {
            return URL(string: avatar)
        }
        let server = APIConfig.baseURL.replacingOccurrences(of: "/api", with: "")
        return URL(string: server + avatar)
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
