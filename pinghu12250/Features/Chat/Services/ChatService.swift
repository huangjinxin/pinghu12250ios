//
//  ChatService.swift
//  pinghu12250
//
//  聊天服务 - 对接 bot/chatMessage/scan API
//

import Foundation

@MainActor
class ChatService {
    static let shared = ChatService()
    private let api = APIService.shared

    // MARK: - Bot

    func fetchBots() async throws -> [Bot] {
        let resp: APIResponse<[Bot]> = try await api.get(APIConfig.Endpoints.bots)
        return resp.data ?? []
    }

    // MARK: - Conversations

    func fetchConversations() async throws -> [Conversation] {
        let resp: APIResponse<[Conversation]> = try await api.get(APIConfig.Endpoints.chatConversations)
        return resp.data ?? []
    }

    // MARK: - Messages

    func fetchMessages(botId: String, cursor: String? = nil, limit: Int = 30) async throws -> [ChatMessage] {
        var query: [URLQueryItem] = [URLQueryItem(name: "limit", value: "\(limit)")]
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        let endpoint = "\(APIConfig.Endpoints.chatMessages)/\(botId)/messages"
        let resp: APIResponse<[ChatMessage]> = try await api.get(endpoint, queryItems: query)
        return resp.data ?? []
    }

    // MARK: - Send

    func sendMessage(botId: String, content: String) async throws -> SendMessageResponse {
        let body = SendMessageRequest(msgType: "text", content: content, cardData: nil)
        let endpoint = "\(APIConfig.Endpoints.chatSend)/\(botId)/send"
        let resp: APIResponse<SendMessageResponse> = try await api.post(endpoint, body: body)
        guard let data = resp.data else { throw APIError.noData }
        return data
    }

    // MARK: - Read

    func markRead(conversationId: String) async throws {
        let endpoint = "\(APIConfig.Endpoints.chatRead)/\(conversationId)/read"
        let _: APIResponse<String?> = try await api.post(endpoint)
    }

    // MARK: - Scan

    func scan(type: String, target: String) async throws -> ScanResult {
        let body = ScanRequest(scanType: type, target: target, params: nil)
        let resp: APIResponse<ScanResult> = try await api.post(APIConfig.Endpoints.scan, body: body)
        guard let data = resp.data else { throw APIError.noData }
        return data
    }
}
