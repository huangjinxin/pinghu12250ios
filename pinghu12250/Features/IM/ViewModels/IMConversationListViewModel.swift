//
//  IMConversationListViewModel.swift
//  pinghu12250
//
//  会话列表ViewModel
//

import Foundation
import Combine

@MainActor
class IMConversationListViewModel: ObservableObject {
    @Published var conversations: [IMConversation] = []
    @Published var totalUnread: Int = 0
    @Published var isLoading = false
    @Published var error: String?

    private let imService = IMService.shared
    private let socketManager = SocketManager.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupSocketListeners()
        setupNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: NSNotification.Name("MessageSent"))
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadConversations()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - 加载会话列表

    func loadConversations() async {
        isLoading = true
        defer { isLoading = false }

        do {
            conversations = try await imService.fetchConversations()
            totalUnread = conversations.reduce(0) { $0 + $1.unreadCount }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Socket监听

    private func setupSocketListeners() {
        // 监听新消息，更新会话列表
        socketManager.onNewMessage { [weak self] message in
            guard let self = self else { return }
            Task { @MainActor in
                self.updateConversationWithNewMessage(message)
            }
        }
    }

    // MARK: - 更新会话

    private func updateConversationWithNewMessage(_ message: IMMessage) {
        // 查找对应会话
        if let index = conversations.firstIndex(where: { conv in
            conv.id == message.fromUserId || conv.username == message.fromUser?.username
        }) {
            // 更新现有会话
            var updatedConv = conversations[index]
            updatedConv.lastMessage = message.content
            updatedConv.lastMessageTime = message.createdAt
            updatedConv.unreadCount += 1

            // 移到列表顶部
            conversations.remove(at: index)
            conversations.insert(updatedConv, at: 0)

            // 更新总未读数
            totalUnread += 1
        } else {
            // 新会话，重新加载列表
            Task {
                await loadConversations()
            }
        }
    }

    // MARK: - 标记已读

    func markConversationAsRead(userId: String) async {
        guard let index = conversations.firstIndex(where: { $0.id == userId }) else { return }

        let oldUnread = conversations[index].unreadCount
        conversations[index].unreadCount = 0
        totalUnread -= oldUnread

        try? await imService.markAsRead(friendId: userId)
    }
}
