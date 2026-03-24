//
//  IMMessageBubble.swift
//  pinghu12250
//
//  IM消息气泡
//

import SwiftUI

struct IMMessageBubble: View {
    let message: IMMessage
    var onRetry: (() -> Void)? = nil
    @EnvironmentObject var authManager: AuthManager

    private var isFromMe: Bool {
        message.fromUserId == authManager.currentUser?.id
    }

    var body: some View {
        HStack {
            if isFromMe { Spacer() }

            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isFromMe ? Color.blue : Color(.systemGray5))
                    .foregroundColor(isFromMe ? .white : .primary)
                    .cornerRadius(16)

                // 消息状态
                if isFromMe {
                    statusView
                }
            }

            if !isFromMe { Spacer() }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch message.status ?? .received {
        case .sending:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("发送中")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        case .sent:
            Text("已发送")
                .font(.caption2)
                .foregroundColor(.secondary)
        case .failed:
            Button(action: { onRetry?() }) {
                Text("发送失败，点击重试")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        case .received:
            EmptyView()
        }
    }
}
