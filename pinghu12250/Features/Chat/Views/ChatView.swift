//
//  ChatView.swift
//  pinghu12250
//
//  聊天界面 - iMessage 风格
//

import SwiftUI

struct ChatView: View {
    let bot: Bot
    @Binding var path: NavigationPath
    var autoSendKeyword: String? = nil
    @StateObject private var vm = ChatViewModel()
    @State private var inputText = ""
    @State private var didAutoSend = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(vm.messages) { msg in
                            if msg.msgType == "card", let card = msg.cardData {
                                CardMessageView(card: card, isUser: msg.isUser) { dest in
                                    path.append(dest)
                                }
                                .id(msg.id)
                            } else {
                                MessageBubble(message: msg)
                                    .id(msg.id)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                }
                .onChange(of: vm.messages.count) { _, _ in
                    if let last = vm.messages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            .onTapGesture { inputFocused = false }

            Divider()
            chatInputBar
        }
        .navigationTitle(bot.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: bot.id) {
            await vm.loadMessages(botId: bot.id)
            if let keyword = autoSendKeyword, !didAutoSend {
                didAutoSend = true
                await vm.send(botId: bot.id, text: keyword)
            }
        }
    }

    // MARK: - 输入栏 (iMessage 风格)

    private var chatInputBar: some View {
        HStack(spacing: 8) {
            TextField("输入消息...", text: $inputText, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6), in: Capsule())
                .focused($inputFocused)

            if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    let text = inputText
                    inputText = ""
                    Task { await vm.send(botId: bot.id, text: text) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.blue)
                }
                .disabled(vm.isSending)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
