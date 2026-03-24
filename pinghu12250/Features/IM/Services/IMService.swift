//
//  IMService.swift
//  pinghu12250
//
//  IM REST API服务
//

import Foundation

class IMService {
    static let shared = IMService()
    private let api = APIService.shared

    private init() {}

    // MARK: - 会话列表

    func fetchConversations() async throws -> [IMConversation] {
        let response: ConversationsResponse = try await api.get("/api/messages/conversations/list")
        return response.data
    }

    // MARK: - 聊天记录

    func fetchMessages(userId: String, page: Int = 1, limit: Int = 50) async throws -> [IMMessage] {
        let endpoint = "/api/messages/\(userId)"
        let queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        let response: MessagesEnvelopeResponse = try await api.get(endpoint, queryItems: queryItems)
        return response.data.messages
    }

    // MARK: - 标记已读

    func markAsRead(friendId: String) async throws {
        struct MarkReadRequest: Encodable {
            let friendId: String
        }
        struct MarkReadResponse: Decodable {
            let success: Bool
            let data: MarkReadData
        }
        struct MarkReadData: Decodable {
            let count: Int
        }

        let _: MarkReadResponse = try await api.post(
            "/api/messages/mark-chat-read",
            body: MarkReadRequest(friendId: friendId)
        )
    }

    // MARK: - 未读总数

    func fetchUnreadCount() async throws -> Int {
        struct UnreadResponse: Decodable {
            let success: Bool
            let data: UnreadData
        }
        struct UnreadData: Decodable {
            let unreadCount: Int
        }

        let response: UnreadResponse = try await api.get("/api/messages/unread/count")
        return response.data.unreadCount
    }

    // MARK: - 发送消息（REST 主通道）

    struct SendMessageResponse: Decodable {
        let success: Bool
        let data: SendMessageData
    }

    struct SendMessageData: Decodable {
        let message: IMMessage
        let conversation: IMConversationPreview
    }

    struct IMConversationPreview: Decodable {
        let id: String
        let lastMessage: String
        let lastMessageTime: String
        let unreadCount: Int
    }

    func sendMessage(toUserId: String, content: String) async throws -> SendMessageData {
        struct SendRequest: Encodable {
            let toUserId: String
            let content: String
        }

        let response: SendMessageResponse = try await api.post(
            "/api/messages/send",
            body: SendRequest(toUserId: toUserId, content: content)
        )
        return response.data
    }

    // MARK: - 创建或获取会话

    struct ConversationOpenEnvelope: Decodable {
        let success: Bool
        let data: ConversationOpenResult
    }

    struct ConversationOpenResult: Decodable {
        let conversationId: String
        let peerUserId: String?
        let peerName: String?
        let peerAvatar: String?
        let created: Bool?
    }

    func createOrGetConversation(friendId: String) async throws -> ConversationOpenResult {
        struct CreateConversationRequest: Encodable {
            let friendId: String
        }
        let response: ConversationOpenEnvelope = try await api.post(
            "/api/conversations/create-or-get",
            body: CreateConversationRequest(friendId: friendId)
        )
        return response.data
    }
}
