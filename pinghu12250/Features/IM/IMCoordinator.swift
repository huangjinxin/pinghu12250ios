//
//  IMCoordinator.swift
//  pinghu12250
//
//  IM 关系与路由协调层
//  会话数据委托给 IMConversationStore
//  消息数据委托给 IMMessageStore
//

import Foundation
import Combine

@MainActor
class IMCoordinator: ObservableObject {
    static let shared = IMCoordinator()

    // MARK: - Child Stores

    let conversationStore = IMConversationStore.shared
    let messageStore = IMMessageStore.shared

    // MARK: - Published State (关系层)

    @Published var friends: [User] = []
    @Published var pendingRequestCount: Int = 0

    // MARK: - Services

    private let friendService = FriendService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    private init() {
        setupNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .friendAdded)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshAfterFriendChange()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .messageSent)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.conversationStore.loadConversations()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Pass-through Conversation API

    var conversations: [IMConversation] { conversationStore.conversations }
    var routeState: IMRouteState { conversationStore.routeState }
    var selectedConversation: IMConversation? { conversationStore.selectedConversation }
    var selectedConversationId: String? { conversationStore.selectedConversationId }
    var pendingSelectionUserId: String? { conversationStore.pendingSelectionUserId }

    func selectConversation(_ conversation: IMConversation) {
        conversationStore.selectConversation(conversation)
    }

    func clearSelection() {
        conversationStore.clearSelection()
    }

    func openConversation(userId: String) async {
        await conversationStore.openConversation(userId: userId)
    }

    func retryOpenConversation() async {
        await conversationStore.retryOpenConversation()
    }

    func loadConversations() async {
        await conversationStore.loadConversations()
    }

    // MARK: - Relationship Data Loading

    func loadFriends() async {
        do {
            friends = try await friendService.getFriends()
        } catch {
            print("❌ 加载好友列表失败: \(error)")
        }
    }

    func loadPendingRequestCount() async {
        do {
            let response: APIResponse<[FriendRequest]> = try await APIService.shared.get("/api/friend-requests/received")
            pendingRequestCount = (response.data ?? []).filter { $0.status == "PENDING" }.count
        } catch {
            print("❌ 加载好友申请数失败: \(error)")
        }
    }

    func refreshAll() async {
        async let c: () = conversationStore.loadConversations()
        async let f: () = loadFriends()
        async let p: () = loadPendingRequestCount()
        _ = await (c, f, p)
    }

    private func refreshAfterFriendChange() async {
        async let f: () = loadFriends()
        async let p: () = loadPendingRequestCount()
        async let c: () = conversationStore.loadConversations()
        _ = await (f, p, c)
    }
}
