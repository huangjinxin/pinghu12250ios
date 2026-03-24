//
//  ChatModels.swift
//  pinghu12250
//
//  聊天模块数据模型
//

import Foundation

// MARK: - Bot

struct Bot: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let type: String?
    let avatar: String?
    let description: String?
    let welcome: String?
    let isActive: Bool?
    let sortOrder: Int?
}

// MARK: - Conversation

struct Conversation: Codable, Identifiable {
    let id: String
    let botId: String
    let userId: String
    let lastMessageAt: String?
    let unreadCount: Int?
    let bot: Bot?
    let messages: [ChatMessage]?
}

// MARK: - ChatMessage

struct ChatMessage: Codable, Identifiable {
    let id: String
    let conversationId: String?
    let senderType: String // "USER" or "BOT"
    let msgType: String // "text", "card", "image"
    let content: String?
    let cardData: CardData?
    let createdAt: String?

    var isUser: Bool { senderType == "USER" }
}

// MARK: - Navigation Destination

enum ChatDestination: Hashable {
    case writing
    case diary
    case reading
    case works(subTab: String? = nil)
    case dashboard
    case wallet
    case photos
    case homework
    case notes
    case growth

    /// Map backend card target string to destination
    static func from(target: String) -> ChatDestination? {
        switch target {
        case "/writing": return .writing
        case "/diary", "/diaries": return .diary
        case "/books": return .reading
        case "/poetry": return .works(subTab: "poetry")
        case "/works": return .works()
        case "/submit", "/points", "/dashboard": return .dashboard
        case "/wallet": return .wallet
        case "/photos": return .photos
        case "/homework": return .homework
        case "/notes": return .notes
        case "/growth": return .growth
        default: return nil
        }
    }
}

// MARK: - CardData

struct CardData: Codable {
    let cardType: String? // "navigate"
    let title: String?
    let description: String?
    let target: String? // navigation path e.g. "/books"
    let icon: String?
}

// MARK: - Send Message

struct SendMessageRequest: Encodable {
    let msgType: String
    let content: String?
    let cardData: CardData?
}

struct SendMessageResponse: Decodable {
    let userMsg: ChatMessage
    let botReply: ChatMessage?
}

// MARK: - Scan

struct ScanRequest: Encodable {
    let scanType: String
    let target: String
    let params: [String: String]?
}

struct ScanNavigation: Decodable {
    let type: String?
    let target: String?
}

struct ScanResult: Decodable {
    let log: ScanLog?
    let navigation: ScanNavigation?
}

struct ScanLog: Codable, Identifiable {
    let id: String
    let scanType: String?
    let target: String?
    let createdAt: String?
}

// MARK: - Chat Navigation (QR scan → chat with keyword)

struct ChatNavigation: Hashable {
    let bot: Bot
    let keyword: String?
}
