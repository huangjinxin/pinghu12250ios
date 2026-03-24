//
//  MockConversations.swift
//  pinghu12250
//
//  Mock 会话数据
//

import Foundation

extension Conversation {
    static let mockConversations: [Conversation] = [
        Conversation(
            id: UUID().uuidString,
            botId: "ai-assistant",
            userId: "user1",
            lastMessageAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-60)),
            unreadCount: 2,
            bot: Bot(
                id: "ai-assistant",
                name: "AI学习助手",
                type: "assistant",
                avatar: "brain.head.profile",
                description: "智能学习助手",
                welcome: "你好！今天学什么？",
                isActive: true,
                sortOrder: 1
            ),
            messages: []
        ),
        Conversation(
            id: UUID().uuidString,
            botId: "teacher-wang",
            userId: "user1",
            lastMessageAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-600)),
            unreadCount: 0,
            bot: Bot(
                id: "teacher-wang",
                name: "王老师",
                type: "teacher",
                avatar: "person.fill",
                description: "语文老师",
                welcome: "有什么问题吗？",
                isActive: true,
                sortOrder: 2
            ),
            messages: []
        ),
        Conversation(
            id: UUID().uuidString,
            botId: "class-group",
            userId: "user1",
            lastMessageAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600)),
            unreadCount: 5,
            bot: Bot(
                id: "class-group",
                name: "五年级1班",
                type: "group",
                avatar: "person.3.fill",
                description: "班级群",
                welcome: "欢迎加入班级群",
                isActive: true,
                sortOrder: 3
            ),
            messages: []
        ),
        Conversation(
            id: UUID().uuidString,
            botId: "parent",
            userId: "user1",
            lastMessageAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400)),
            unreadCount: 0,
            bot: Bot(
                id: "parent",
                name: "妈妈",
                type: "parent",
                avatar: "heart.fill",
                description: "家长",
                welcome: "今天表现好吗？",
                isActive: true,
                sortOrder: 4
            ),
            messages: []
        )
    ]
}
