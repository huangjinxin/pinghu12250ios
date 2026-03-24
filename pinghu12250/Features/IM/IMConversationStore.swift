//
//  IMConversationStore.swift
//  pinghu12250
//
//  会话状态存储
//

import Foundation
import Combine

@MainActor
class IMConversationStore: ObservableObject {
    static let shared = IMConversationStore()

    @Published private(set) var conversations: [IMConversation] = []
    @Published private(set) var routeState: IMRouteState = .idle
    @Published private(set) var selectedConversationId: String?
    @Published private(set) var pendingSelectionUserId: String?
    @Published private(set) var lastFailedUserId: String?

    private let imService = IMService.shared

    private init() {
        conversations = IMPersistence.loadConversations()
    }

    var selectedConversation: IMConversation? {
        guard let selectedConversationId else { return nil }
        return conversations.first(where: { $0.id == selectedConversationId })
    }

    func loadConversations() async {
        do {
            let remoteConversations = try await imService.fetchConversations()
            conversations = mergeConversations(local: conversations, remote: remoteConversations)
            IMPersistence.saveConversations(conversations)

            if let pendingSelectionUserId,
               conversations.contains(where: { $0.id == pendingSelectionUserId }) {
                activateConversation(userId: pendingSelectionUserId)
            }
        } catch {
            print("❌ 加载会话列表失败: \(error)")
        }
    }

    func selectConversation(_ conversation: IMConversation) {
        activateConversation(userId: conversation.id)
    }

    func clearSelection() {
        selectedConversationId = nil
        pendingSelectionUserId = nil
        routeState = .idle
    }

    func openConversation(userId: String) async {
        pendingSelectionUserId = userId
        routeState = .openingConversation(userId: userId)
        lastFailedUserId = nil

        do {
            let result = try await imService.createOrGetConversation(friendId: userId)
            print("✅ 会话已创建/获取: \(result.conversationId)")

            for attempt in 1...3 {
                await loadConversations()

                if conversations.contains(where: { $0.id == userId }) {
                    activateConversation(userId: userId)
                    print("✅ 会话已就绪 (第\(attempt)次)")
                    return
                }

                if attempt < 3 {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                }
            }

            let tempConversation = IMConversation(
                id: result.peerUserId ?? userId,
                username: result.peerName ?? userId,
                name: result.peerName ?? userId,
                avatar: result.peerAvatar,
                lastMessage: nil,
                lastMessageTime: nil,
                unreadCount: 0
            )

            upsertConversation(tempConversation, moveToTop: true)
            activateConversation(userId: tempConversation.id, syncRead: false)
            print("⚠️ 使用后端返回信息构造临时会话进入聊天")
        } catch {
            lastFailedUserId = userId
            routeState = .failed("无法打开会话: \(error.localizedDescription)")
            print("❌ 打开会话失败: \(error)")
        }
    }

    func retryOpenConversation() async {
        guard let lastFailedUserId else {
            routeState = .idle
            return
        }
        await openConversation(userId: lastFailedUserId)
    }

    func updateConversationPreview(for userId: String, lastMessage: String, lastMessageTime: String) {
        var conversation = conversations.first(where: { $0.id == userId }) ?? IMConversation(
            id: userId,
            username: userId,
            name: userId,
            avatar: nil,
            lastMessage: nil,
            lastMessageTime: nil,
            unreadCount: 0
        )

        conversation.lastMessage = lastMessage
        conversation.lastMessageTime = lastMessageTime
        if selectedConversationId == userId {
            conversation.unreadCount = 0
        }
        upsertConversation(conversation, moveToTop: true)
    }

    func applyIncomingMessagePreview(for userId: String, lastMessage: String, lastMessageTime: String) {
        var conversation = conversations.first(where: { $0.id == userId }) ?? IMConversation(
            id: userId,
            username: userId,
            name: userId,
            avatar: nil,
            lastMessage: nil,
            lastMessageTime: nil,
            unreadCount: 0
        )

        conversation.lastMessage = lastMessage
        conversation.lastMessageTime = lastMessageTime
        if selectedConversationId == userId {
            conversation.unreadCount = 0
        } else {
            conversation.unreadCount += 1
        }
        upsertConversation(conversation, moveToTop: true)
    }

    func markConversationAsReadLocally(userId: String) {
        guard let index = conversations.firstIndex(where: { $0.id == userId }) else { return }
        guard conversations[index].unreadCount > 0 else { return }
        conversations[index].unreadCount = 0
        IMPersistence.saveConversations(conversations)
    }

    // MARK: - Helpers

    private func activateConversation(userId: String, syncRead: Bool = true) {
        selectedConversationId = userId
        pendingSelectionUserId = nil
        routeState = .idle
        let hadUnread = conversations.first(where: { $0.id == userId })?.unreadCount ?? 0
        markConversationAsReadLocally(userId: userId)

        guard syncRead, hadUnread > 0 else { return }
        Task {
            try? await imService.markAsRead(friendId: userId)
        }
    }

    private func upsertConversation(_ conversation: IMConversation, moveToTop: Bool) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations.remove(at: index)
        }
        if moveToTop {
            conversations.insert(conversation, at: 0)
        } else {
            conversations.append(conversation)
        }
        IMPersistence.saveConversations(conversations)
    }

    private func mergeConversations(local: [IMConversation], remote: [IMConversation]) -> [IMConversation] {
        var merged: [String: IMConversation] = [:]

        for conversation in local {
            merged[conversation.id] = conversation
        }

        for remoteConversation in remote {
            if let localConversation = merged[remoteConversation.id] {
                let keepLocal = (localConversation.lastMessageTime ?? "") > (remoteConversation.lastMessageTime ?? "")
                merged[remoteConversation.id] = keepLocal ? localConversation : remoteConversation
            } else {
                merged[remoteConversation.id] = remoteConversation
            }
        }

        return Array(merged.values).sorted { a, b in
            switch (a.lastMessageTime, b.lastMessageTime) {
            case let (lhs?, rhs?):
                return lhs > rhs
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return a.id < b.id
            }
        }
    }
}
