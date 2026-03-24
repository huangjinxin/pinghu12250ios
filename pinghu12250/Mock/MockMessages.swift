//
//  MockMessages.swift
//  pinghu12250
//
//  Mock 消息数据（包含卡片）
//

import Foundation

extension ChatMessage {
    static let mockMessages: [ChatMessage] = [
        // 用户消息
        ChatMessage(
            id: UUID().uuidString,
            conversationId: "conv1",
            senderType: "USER",
            msgType: "text",
            content: "你好！今天学什么？",
            cardData: nil,
            createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-300))
        ),

        // AI回复 - 文本
        ChatMessage(
            id: UUID().uuidString,
            conversationId: "conv1",
            senderType: "BOT",
            msgType: "text",
            content: "你好！给你推荐几本教材：",
            cardData: nil,
            createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-290))
        ),

        // AI回复 - 教材卡片
        ChatMessage(
            id: UUID().uuidString,
            conversationId: "conv1",
            senderType: "BOT",
            msgType: "card",
            content: "",
            cardData: CardData(
                cardType: "textbook",
                title: "语文五年级上册",
                description: "第3课：桂林山水 | 进度: 45%",
                target: "/textbook/1",
                icon: "book.fill"
            ),
            createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-280))
        ),

        // 用户消息
        ChatMessage(
            id: UUID().uuidString,
            conversationId: "conv1",
            senderType: "USER",
            msgType: "text",
            content: "我想学语文第3课",
            cardData: nil,
            createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-120))
        ),

        // AI回复 - 作业卡片
        ChatMessage(
            id: UUID().uuidString,
            conversationId: "conv1",
            senderType: "BOT",
            msgType: "card",
            content: "",
            cardData: CardData(
                cardType: "homework",
                title: "今日作业",
                description: "语文：背诵第3课\n数学：练习册P12-15\n截止: 今天 20:00",
                target: "/homework/1",
                icon: "pencil"
            ),
            createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-60))
        )
    ]
}
