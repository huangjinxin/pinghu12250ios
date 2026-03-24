//
//  IMMessageStore.swift
//  pinghu12250
//
//  消息状态存储
//

import Foundation
import Combine

@MainActor
class IMMessageStore: ObservableObject {
    static let shared = IMMessageStore()

    @Published private(set) var messagesByUserId: [String: [IMMessage]] = [:]
    @Published private(set) var loadingUserIds: Set<String> = []
    @Published private(set) var sendingUserIds: Set<String> = []
    @Published private(set) var errorsByUserId: [String: String] = [:]

    private let imService = IMService.shared
    private let conversationStore = IMConversationStore.shared
    private let socketManager = SocketManager.shared

    private init() {
        setupSocketListeners()
    }

    private func setupSocketListeners() {
        socketManager.onNewMessage { [weak self] message in
            guard let self = self else { return }
            Task { @MainActor in
                let userId = message.fromUserId

                var messages = self.messagesByUserId[userId] ?? []
                if !messages.contains(where: { $0.id == message.id }) {
                    messages.append(message)
                    messages.sort { $0.createdAt < $1.createdAt }
                    self.messagesByUserId[userId] = messages
                }

                self.conversationStore.applyIncomingMessagePreview(
                    for: userId,
                    lastMessage: message.content,
                    lastMessageTime: message.createdAt
                )

                if self.conversationStore.selectedConversationId == userId {
                    self.conversationStore.markConversationAsReadLocally(userId: userId)
                    try? await self.imService.markAsRead(friendId: userId)
                } else {
                    NotificationCenter.default.post(
                        name: .imIncomingBanner,
                        object: nil,
                        userInfo: [
                            "userId": userId,
                            "content": message.content,
                            "sender": message.fromUser?.username ?? userId
                        ]
                    )
                }
            }
        }
    }

    func messages(for userId: String) -> [IMMessage] {
        messagesByUserId[userId] ?? []
    }

    func isLoading(for userId: String) -> Bool {
        loadingUserIds.contains(userId)
    }

    func isSending(for userId: String) -> Bool {
        sendingUserIds.contains(userId)
    }

    func error(for userId: String) -> String? {
        errorsByUserId[userId]
    }

    func clearError(for userId: String) {
        errorsByUserId[userId] = nil
    }

    func loadMessages(userId: String) async {
        loadingUserIds.insert(userId)
        defer { loadingUserIds.remove(userId) }

        do {
            let fetchedMessages = try await imService.fetchMessages(userId: userId)
            let sorted = fetchedMessages.sorted { $0.createdAt < $1.createdAt }
            messagesByUserId[userId] = sorted
            IMPersistence.saveMessages(sorted, for: userId)
            errorsByUserId[userId] = nil
            conversationStore.markConversationAsReadLocally(userId: userId)
            try? await imService.markAsRead(friendId: userId)
        } catch {
            errorsByUserId[userId] = error.localizedDescription
            print("❌ 加载消息失败: \(error)")
        }
    }

    func sendMessage(userId: String, content: String) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let currentUserId = AuthManager.shared.currentUser?.id ?? ""
        let tempId = UUID().uuidString
        let tempMessage = IMMessage(
            id: tempId,
            conversationId: nil,
            fromUserId: currentUserId,
            toUserId: userId,
            content: content,
            status: .sending,
            isRead: true,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            fromUser: nil as MessageUser?,
            tempId: tempId
        )

        var currentMessages = messagesByUserId[userId] ?? IMPersistence.loadMessages(for: userId)
        currentMessages.append(tempMessage)
        messagesByUserId[userId] = currentMessages
        IMPersistence.saveMessages(currentMessages, for: userId)
        sendingUserIds.insert(userId)
        errorsByUserId[userId] = nil

        do {
            let sentResult = try await imService.sendMessage(toUserId: userId, content: content)
            if var messages = messagesByUserId[userId],
               let index = messages.firstIndex(where: { $0.tempId == tempId }) {
                var realMessage = sentResult.message
                realMessage.status = .sent
                messages[index] = realMessage
                messagesByUserId[userId] = messages
                IMPersistence.saveMessages(messages, for: userId)
            }

            // 立即更新会话列表预览（像微信一样）
            conversationStore.updateConversationPreview(
                for: userId,
                lastMessage: sentResult.conversation.lastMessage,
                lastMessageTime: sentResult.conversation.lastMessageTime
            )

            sendingUserIds.remove(userId)
            NotificationCenter.default.post(name: .messageSent, object: nil)
        } catch {
            if var messages = messagesByUserId[userId],
               let index = messages.firstIndex(where: { $0.tempId == tempId }) {
                messages[index].status = .failed
                messagesByUserId[userId] = messages
                IMPersistence.saveMessages(messages, for: userId)
            }
            sendingUserIds.remove(userId)
            errorsByUserId[userId] = "发送失败: \(error.localizedDescription)"
            print("❌ 发送消息失败: \(error)")
        }
    }

    func retrySendMessage(userId: String, message: IMMessage) async {
        guard message.status == .failed else { return }
        if var messages = messagesByUserId[userId] {
            messages.removeAll { $0.id == message.id }
            messagesByUserId[userId] = messages
        }
        await sendMessage(userId: userId, content: message.content)
    }
}
