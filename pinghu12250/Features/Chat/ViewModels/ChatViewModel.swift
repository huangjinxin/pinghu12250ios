//
//  ChatViewModel.swift
//  pinghu12250
//
//  聊天状态管理
//

import SwiftUI
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var bots: [Bot] = []
    @Published var conversations: [Conversation] = []
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var isSending = false
    @Published var error: String?

    private let service = ChatService.shared

    // MARK: - Bot列表 + 会话列表

    func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let b = service.fetchBots()
            async let c = service.fetchConversations()
            let (fetchedBots, fetchedConvs) = try await (b, c)
            bots = fetchedBots.filter { $0.isActive == true }
            conversations = fetchedConvs
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadConversations() async {
        do {
            conversations = try await service.fetchConversations()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Find existing conversation for a bot
    func conversation(for botId: String) -> Conversation? {
        conversations.first { $0.botId == botId }
    }

    // MARK: - 消息

    func loadMessages(botId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            messages = try await service.fetchMessages(botId: botId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func send(botId: String, text: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSending = true
        defer { isSending = false }
        do {
            let resp = try await service.sendMessage(botId: botId, content: text)
            messages.append(resp.userMsg)
            if let reply = resp.botReply {
                messages.append(reply)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func markRead(conversationId: String) async {
        try? await service.markRead(conversationId: conversationId)
    }

    // MARK: - 加载更多

    func loadMore(botId: String) async {
        guard let oldest = messages.first else { return }
        do {
            let older = try await service.fetchMessages(botId: botId, cursor: oldest.id)
            if !older.isEmpty {
                messages.insert(contentsOf: older, at: 0)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
