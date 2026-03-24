//
//  IMChatViewModel.swift
//  pinghu12250
//
//  聊天页面ViewModel（包装层）
//  核心消息状态已下沉到 IMMessageStore
//

import Foundation
import Combine

@MainActor
class IMChatViewModel: ObservableObject {
    @Published var messages: [IMMessage] = []
    @Published var isSending = false
    @Published var isLoading = false
    @Published var error: String?

    private let messageStore = IMMessageStore.shared
    private var cancellables = Set<AnyCancellable>()

    let friendUserId: String

    init(friendUserId: String) {
        self.friendUserId = friendUserId
        bindStore()
    }

    private func bindStore() {
        messageStore.$messagesByUserId
            .receive(on: DispatchQueue.main)
            .sink { [weak self] allMessages in
                guard let self = self else { return }
                self.messages = allMessages[self.friendUserId] ?? []
            }
            .store(in: &cancellables)

        messageStore.$loadingUserIds
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loadingIds in
                guard let self = self else { return }
                self.isLoading = loadingIds.contains(self.friendUserId)
            }
            .store(in: &cancellables)

        messageStore.$sendingUserIds
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sendingIds in
                guard let self = self else { return }
                self.isSending = sendingIds.contains(self.friendUserId)
            }
            .store(in: &cancellables)

        messageStore.$errorsByUserId
            .receive(on: DispatchQueue.main)
            .sink { [weak self] errors in
                guard let self = self else { return }
                self.error = errors[self.friendUserId]
            }
            .store(in: &cancellables)
    }

    func clearTransientState() {
        error = nil
    }

    func loadMessages() async {
        await messageStore.loadMessages(userId: friendUserId)
    }

    func sendMessage(content: String) {
        Task { await messageStore.sendMessage(userId: friendUserId, content: content) }
    }

    func retrySendMessage(_ message: IMMessage) {
        Task { await messageStore.retrySendMessage(userId: friendUserId, message: message) }
    }

    func clearError() {
        messageStore.clearError(for: friendUserId)
    }
}
