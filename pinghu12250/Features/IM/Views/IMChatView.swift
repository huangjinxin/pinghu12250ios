//
//  IMChatView.swift
//  pinghu12250
//
//  IM聊天界面
//

import SwiftUI

struct IMChatView: View {
    let friendUserId: String
    let friendName: String

    @StateObject private var viewModel: IMChatViewModel
    @State private var inputText = ""
    @FocusState private var inputFocused: Bool

    init(friendUserId: String, friendName: String) {
        self.friendUserId = friendUserId
        self.friendName = friendName
        _viewModel = StateObject(wrappedValue: IMChatViewModel(friendUserId: friendUserId))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            chatHeader

            Divider()

            // 消息列表
            ScrollViewReader { proxy in
                ScrollView {
                    if viewModel.isLoading {
                        ProgressView("加载消息中...")
                            .padding(.top, 40)
                    } else if viewModel.messages.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 40))
                                .foregroundColor(Color(.systemGray3))
                            Text("暂无消息，发送第一条消息吧")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.messages) { message in
                                IMMessageBubble(message: message) {
                                    viewModel.retrySendMessage(message)
                                }
                                .id(message.id)
                            }
                        }
                        .padding()
                    }
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let lastId = viewModel.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }
            .onTapGesture {
                inputFocused = false
            }

            Divider()

            if let error = viewModel.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))

                Divider()
            }

            // 输入框
            inputBar
        }
        .background(Color(.systemBackground))
        .task(id: friendUserId) {
            inputText = ""
            inputFocused = false
            viewModel.clearTransientState()
            await viewModel.loadMessages()
        }
    }

    // MARK: - 顶部标题栏

    private var chatHeader: some View {
        HStack {
            // 头像
            Circle()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(friendName.prefix(1)))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(friendName)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    // MARK: - 输入框

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("输入消息...", text: $inputText, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .focused($inputFocused)

            Button {
                let text = inputText
                inputText = ""
                viewModel.sendMessage(content: text)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(canSend ? .blue : Color(.systemGray4))
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isSending
    }
}
