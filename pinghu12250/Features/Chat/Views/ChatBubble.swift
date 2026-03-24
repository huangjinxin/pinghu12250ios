//
//  ChatBubble.swift
//  pinghu12250
//
//  消息气泡 - iMessage 风格
//

import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 60) }

            if message.msgType == "card", let card = message.cardData {
                CardMessageView(card: card, isUser: message.isUser) { _ in }
            } else {
                Text(message.content ?? "")
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(message.isUser ? Color.blue : Color(.systemGray5))
                    .foregroundStyle(message.isUser ? .white : .primary)
                    .clipShape(BubbleShape(isUser: message.isUser))
            }

            if !message.isUser { Spacer(minLength: 60) }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - iMessage 气泡形状

struct BubbleShape: Shape {
    let isUser: Bool

    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 18
        let tail: CGFloat = 6
        var path = Path()

        if isUser {
            // 右侧气泡，右下角有尾巴
            path.addRoundedRect(in: CGRect(x: 0, y: 0, width: rect.width - tail, height: rect.height), cornerSize: CGSize(width: r, height: r))
            // 尾巴
            path.move(to: CGPoint(x: rect.width - tail, y: rect.height - r))
            path.addQuadCurve(to: CGPoint(x: rect.width, y: rect.height), control: CGPoint(x: rect.width - tail, y: rect.height))
            path.addQuadCurve(to: CGPoint(x: rect.width - tail - 4, y: rect.height), control: CGPoint(x: rect.width - tail, y: rect.height))
        } else {
            // 左侧气泡，左下角有尾巴
            path.addRoundedRect(in: CGRect(x: tail, y: 0, width: rect.width - tail, height: rect.height), cornerSize: CGSize(width: r, height: r))
            path.move(to: CGPoint(x: tail, y: rect.height - r))
            path.addQuadCurve(to: CGPoint(x: 0, y: rect.height), control: CGPoint(x: tail, y: rect.height))
            path.addQuadCurve(to: CGPoint(x: tail + 4, y: rect.height), control: CGPoint(x: tail, y: rect.height))
        }

        return path
    }
}
