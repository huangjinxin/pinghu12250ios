//
//  IMMessage.swift
//  pinghu12250
//
//  IM消息模型
//

import Foundation

enum MessageStatus: String, Codable {
    case sending
    case sent
    case failed
    case received
}

struct IMMessage: Codable, Identifiable, Hashable {
    let id: String
    let conversationId: String?
    let fromUserId: String
    let toUserId: String
    let content: String
    var status: MessageStatus?
    let isRead: Bool?
    let createdAt: String
    let fromUser: MessageUser?
    var tempId: String?

    static func == (lhs: IMMessage, rhs: IMMessage) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct MessageUser: Codable, Hashable {
    let id: String
    let username: String
    let avatar: String?
}

struct IMSendMessageRequest: Encodable {
    let toUserId: String
    let content: String
    let tempId: String
}

struct SocketMessageResponse: Decodable {
    let tempId: String
    let message: IMMessage
}
