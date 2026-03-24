//
//  IMFriendListView.swift
//  pinghu12250
//
//  IM好友列表页面
//

import SwiftUI

struct IMFriendListView: View {
    @State private var friends: [User] = []
    @State private var isLoading = false
    @State private var showAddFriend = false
    @State private var showNewFriends = false

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
            } else {
                VStack(spacing: 0) {
                    // 新的朋友入口
                    Button(action: { showNewFriends = true }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 20))
                                .foregroundColor(.orange)
                                .frame(width: 40, height: 40)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(Circle())

                            Text("新的朋友")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .font(.system(size: 14))
                        }
                        .padding()
                        .background(Color(.systemBackground))
                    }
                    .buttonStyle(.plain)

                    Divider()

                    if friends.isEmpty {
                        emptyView
                    } else {
                        friendsList
                    }
                }
            }
        }
        .navigationTitle("通讯录")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddFriend = true }) {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showAddFriend) {
            IMAddFriendView()
        }
        .sheet(isPresented: $showNewFriends) {
            NavigationView {
                IMNewFriendsView()
            }
        }
        .task {
            await loadFriends()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FriendAdded"))) { _ in
            Task { await loadFriends() }
        }
        .refreshable {
            await loadFriends()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("暂无好友")
                .foregroundColor(.gray)
            Button("添加好友") {
                showAddFriend = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var friendsList: some View {
        List(friends) { friend in
            Button(action: {
                // 导航到聊天页面的逻辑需要在父视图处理
            }) {
                HStack {
                    AsyncImage(url: URL(string: friend.avatar ?? "")) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(.gray)
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())

                    Text(friend.username)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
            }
        }
    }

    private func loadFriends() async {
        isLoading = true
        do {
            friends = try await FriendService.shared.getFriends()
            print("✅ 好友列表加载成功，数量: \(friends.count)")
            print("📋 好友数据: \(friends.map { "\($0.username) (id:\($0.id))" })")
        } catch {
            print("❌ 加载好友列表失败: \(error)")
        }
        isLoading = false
    }
}
