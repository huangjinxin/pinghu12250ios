//
//  IMConversation.swift
//  pinghu12250
//
//  IM会话模型
//

import Foundation

struct IMConversation: Codable, Identifiable, Hashable {
    let id: String
    let username: String
    let name: String
    let avatar: String?
    var lastMessage: String?
    var lastMessageTime: String?
    var unreadCount: Int
    var isOnline: Bool = false

    static func == (lhs: IMConversation, rhs: IMConversation) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct ConversationsResponse: Decodable {
    let success: Bool
    let data: [IMConversation]
}

struct MessagesEnvelopeResponse: Decodable {
    let success: Bool
    let data: MessagesData
}

struct MessagesData: Decodable {
    let messages: [IMMessage]
    let pagination: Pagination
}

struct Pagination: Decodable {
    let page: Int
    let limit: Int
    let total: Int
}
