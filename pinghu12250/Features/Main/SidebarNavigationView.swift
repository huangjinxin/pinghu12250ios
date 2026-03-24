//
//  SidebarNavigationView.swift
//  pinghu12250
//
//  侧边栏导航主布局
//

import SwiftUI

struct SidebarNavigationView: View {
    @State private var selectedMenu: MenuType = .messages
    @StateObject private var imCoordinator = IMCoordinator.shared
    @StateObject private var conversationStore = IMConversationStore.shared
    @StateObject private var socketManager = SocketManager.shared
    @State private var botSelection: Bot?
    @State private var contactSelection: ContactSelection = .none
    @State private var selectedFeedItem: UnifiedFeedItem?
    @State private var selectedMoreItem: String?
    @State private var selectedProfileItem: String?
    @State private var chatPath = NavigationPath()
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // 左侧区域 (1/3)
                VStack(spacing: 0) {
                    connectionStatusBanner
                    MenuButtonsView(selected: $selectedMenu, badges: menuBadges)
                    listContent
                }
                .frame(width: geometry.size.width * 0.33)
                .background(Color.white)
                .overlay(
                    Rectangle()
                        .fill(Color.messageBorder)
                        .frame(width: 1),
                    alignment: .trailing
                )

                // 右侧详情 (2/3)
                detailContent
                    .frame(width: geometry.size.width * 0.67)
            }
        }
        .environmentObject(authManager)
        .environmentObject(imCoordinator)
        .onReceive(NotificationCenter.default.publisher(for: .openConversation)) { notification in
            guard let userId = notification.userInfo?["userId"] as? String else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedMenu = .messages
            }
            chatPath = NavigationPath()
            botSelection = nil
            Task { await imCoordinator.openConversation(userId: userId) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openBotConversation)) { notification in
            guard let botId = notification.userInfo?["botId"] as? String else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedMenu = .messages
            }
            chatPath = NavigationPath()
            imCoordinator.clearSelection()
            pendingBotId = botId
        }
        .onChange(of: botSelection?.id) { _, newValue in
            if newValue != nil {
                chatPath = NavigationPath()
            }
        }
        .task {
            await imCoordinator.refreshAll()
        }
    }

    @State private var pendingBotId: String?

    private var menuBadges: [MenuType: Int] {
        let unread = conversationStore.conversations.reduce(0) { $0 + $1.unreadCount }
        return unread > 0 ? [.messages: unread] : [:]
    }

    @ViewBuilder
    private var connectionStatusBanner: some View {
        switch socketManager.connectionState {
        case .authenticated:
            EmptyView()
        case .connecting:
            statusBanner("正在连接消息服务...", color: .orange)
        case .failed:
            statusBanner("消息服务连接失败", color: .red)
        case .disconnected:
            if authManager.isAuthenticated {
                statusBanner("消息服务已断开", color: .red)
            }
        case .connected:
            statusBanner("消息服务认证中...", color: .orange)
        }
    }

    private func statusBanner(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(color)
    }

    @ViewBuilder
    private var listContent: some View {
        switch selectedMenu {
        case .messages:
            ConversationListSidebarView(
                botSelection: $botSelection,
                pendingBotId: $pendingBotId
            )
        case .contacts:
            FriendListView(selection: $contactSelection)
        case .more:
            MoreMenuView(selectedItem: $selectedMoreItem)
        case .profile:
            ProfileMenuView(selectedItem: $selectedProfileItem)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedMenu {
        case .messages:
            messagesDetailContent
        case .contacts:
            contactsDetailContent
        case .more:
            if let itemId = selectedMoreItem {
                moreDetailView(for: itemId)
            } else {
                emptyView("选择功能查看内容")
            }
        case .profile:
            if let itemId = selectedProfileItem {
                profileDetailView(for: itemId)
            } else {
                emptyView("选择功能查看内容")
            }
        }
    }

    @ViewBuilder
    private func destinationView(for dest: ChatDestination) -> some View {
        switch dest {
        case .wallet: WalletView()
        case .reading: TextbookListView()
        case .diary: DiaryListView()
        case .writing: WritingView()
        case .works: WorksGalleryView()
        case .dashboard: HomeDashboardView()
        case .photos: PhotosView()
        case .homework: HomeworkListView()
        case .notes: AllNotesView()
        case .growth: MyGrowthView()
        }
    }

    @ViewBuilder
    private func moreDetailView(for itemId: String) -> some View {
        switch itemId {
        case "feed":
            if let item = selectedFeedItem {
                FeedDetailView(item: item)
            } else {
                FeedListView(selectedItem: $selectedFeedItem)
            }
        case "exchange": ShoppingView()
        case "textbooks": TextbookListView()
        case "homework": HomeworkListView()
        case "notes": AllNotesView()
        case "works": WorksGalleryView()
        case "dashboard": HomeDashboardView()
        case "photos": PhotosView()
        case "diary-submit": NavigationStack { DiarySubmitView() }
        case "diary": DiaryListView()
        case "writing": WritingView()
        case "pinyin": PinyinView()
        case "growth": MyGrowthView()
        default: emptyView("未知功能")
        }
    }

    @ViewBuilder
    private func profileDetailView(for itemId: String) -> some View {
        switch itemId {
        case "wallet": WalletView()
        case "points": PointsView()
        case "settings": SystemSettingsView()
        case "about": Text("关于")
        default: emptyView("未知功能")
        }
    }

    private func emptyView(_ text: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "square.dashed")
                .font(.system(size: 60))
                .foregroundColor(.messageSecondaryText)
            Text(text)
                .font(.system(size: 18))
                .foregroundColor(.messageSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.messageSecondaryBackground)
    }

    // MARK: - 消息右侧详情（IM 三态 + Bot）

    @ViewBuilder
    private var messagesDetailContent: some View {
        if let bot = botSelection {
            // Bot 会话
            NavigationStack(path: $chatPath) {
                ChatView(bot: bot, path: $chatPath)
                    .navigationDestination(for: ChatDestination.self) { dest in
                        destinationView(for: dest)
                    }
            }
            .id(bot.id)
        } else if case .openingConversation = conversationStore.routeState {
            // 正在打开 IM 会话
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("正在打开会话...")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.messageSecondaryBackground)
        } else if case .failed(let message) = conversationStore.routeState {
            // 打开失败
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Button {
                    Task { await conversationStore.retryOpenConversation() }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("重试")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.appPrimary)
                    .cornerRadius(10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.messageSecondaryBackground)
        } else if let conversation = conversationStore.selectedConversation {
            // 已选中 IM 会话
            IMChatView(friendUserId: conversation.id, friendName: conversation.name)
                .id(conversation.id)
        } else {
            // 空态
            emptyView("选择一个对话开始聊天")
        }
    }

    // MARK: - 通讯录右侧详情

    @ViewBuilder
    private var contactsDetailContent: some View {
        switch contactSelection {
        case .none:
            emptyView("选择联系人查看详情")
        case .addFriend:
            NavigationStack {
                AddFriendEmbeddedView()
            }
        case .newFriends:
            NavigationStack {
                IMNewFriendsView()
            }
        case .aiTeachers:
            AITeacherListView()
        case .friend(let user):
            ContactDetailView(user: user)
        }
    }
}
