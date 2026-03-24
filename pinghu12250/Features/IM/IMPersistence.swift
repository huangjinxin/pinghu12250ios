//
//  IMPersistence.swift
//  pinghu12250
//
//  IM 本地持久化（轻量版）
//

import Foundation

enum IMPersistence {
    private static let conversationsKey = "im.conversations.cache"
    private static let messagesKeyPrefix = "im.messages.cache."

    static func saveConversations(_ conversations: [IMConversation]) {
        if let data = try? JSONEncoder().encode(conversations) {
            UserDefaults.standard.set(data, forKey: conversationsKey)
        }
    }

    static func loadConversations() -> [IMConversation] {
        guard let data = UserDefaults.standard.data(forKey: conversationsKey),
              let conversations = try? JSONDecoder().decode([IMConversation].self, from: data) else {
            return []
        }
        return conversations
    }

    static func saveMessages(_ messages: [IMMessage], for userId: String) {
        let key = messagesKeyPrefix + userId
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func loadMessages(for userId: String) -> [IMMessage] {
        let key = messagesKeyPrefix + userId
        guard let data = UserDefaults.standard.data(forKey: key),
              let messages = try? JSONDecoder().decode([IMMessage].self, from: data) else {
            return []
        }
        return messages
    }
}
