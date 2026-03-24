//
//  CardMessageView.swift
//  pinghu12250
//
//  卡片消息 - 点击push到功能页
//

import SwiftUI

struct CardMessageView: View {
    let card: CardData
    let isUser: Bool
    let onNavigate: (ChatDestination) -> Void

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            Button { navigate() } label: { cardContent }
                .buttonStyle(.plain)
                .frame(maxWidth: 380)
            if !isUser { Spacer(minLength: 40) }
        }
        .padding(.vertical, 6)
    }

    private var cardContent: some View {
        HStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.system(size: 24))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(iconColor, in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(card.title ?? "查看详情")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                if let desc = card.description {
                    Text(desc)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.messageBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }

    private var iconName: String {
        if let icon = card.icon, !icon.isEmpty { return icon }
        guard let target = card.target else { return "arrow.right.circle.fill" }
        switch target {
        case "/books": return "books.vertical.fill"
        case "/poetry": return "scroll.fill"
        case "/writing": return "pencil.tip.crop.circle"
        case "/diary", "/diaries": return "book.closed.fill"
        case "/photos": return "camera.fill"
        case "/submit": return "checklist"
        case "/points": return "star.fill"
        case "/dashboard": return "gauge.with.dots.needle.33percent"
        default: return "arrow.right.circle.fill"
        }
    }

    private var iconColor: Color {
        guard let target = card.target else { return .gray }
        switch target {
        case "/books": return .green
        case "/poetry": return .indigo
        case "/writing": return .brown
        case "/diary", "/diaries": return .purple
        case "/photos": return .teal
        case "/submit": return .blue
        case "/points": return .orange
        default: return .blue
        }
    }

    private func navigate() {
        guard let target = card.target,
              let dest = ChatDestination.from(target: target) else { return }
        onNavigate(dest)
    }
}
