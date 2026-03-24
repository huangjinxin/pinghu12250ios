//
//  IMAddFriendView.swift
//  pinghu12250
//
//  IM添加好友页面
//

import SwiftUI

struct IMAddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @State private var searchText = ""
    @State private var searchResults: [UserSearchResult] = []
    @State private var isSearching = false
    @State private var sentRequests: Set<String> = []
    @State private var acceptedRequests: Set<String> = []
    @State private var addingUserId: String?
    @State private var showScanner = false
    @State private var showMyQRCode = false
    @State private var alertMessage: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    if isSearching {
                        loadingState
                    } else if !searchText.isEmpty {
                        searchContent
                    } else {
                        menuContent
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("添加好友")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showScanner) {
            FriendQRScannerView { userId in
                Task { await handleScannedUser(userId: userId) }
            }
        }
        .sheet(isPresented: $showMyQRCode) {
            NavigationStack {
                MyFriendQRCodeView()
                    .environmentObject(authManager)
            }
        }
        .alert("提示", isPresented: .constant(alertMessage != nil)) {
            Button("确定") { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("账号 / 用户名", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundColor(.primary)
                .onSubmit {
                    Task { await search() }
                }
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }

    private var menuContent: some View {
        VStack(spacing: 0) {
            sectionRow(
                icon: "qrcode.viewfinder",
                iconColor: .blue,
                title: "扫一扫",
                subtitle: "扫描二维码名片"
            ) {
                showScanner = true
            }

            Divider().padding(.leading, 72)

            sectionRow(
                icon: "qrcode",
                iconColor: .green,
                title: "我的二维码",
                subtitle: "展示给对方扫一扫"
            ) {
                showMyQRCode = true
            }

            MyFriendQRCodeCard()
                .environmentObject(authManager)
        }
        .padding(.top, 20)
    }

    private var searchContent: some View {
        VStack(spacing: 0) {
            if searchResults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("未找到用户")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(searchResults) { user in
                        HStack(spacing: 12) {
                            if let avatar = user.avatar, let url = URL(string: avatar), avatar.hasPrefix("http") {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    personPlaceholder
                                }
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                personPlaceholder
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.displayName)
                                    .font(.system(size: 16, weight: .medium))
                                Text(user.username)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if user.isFriend || acceptedRequests.contains(user.id) {
                                Button("发消息") {
                                    dismiss()
                                    IMNavigationHelper.openFriendChat(userId: user.id)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            } else if user.requestStatus == "SENT" || sentRequests.contains(user.id) {
                                Text("已发送")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            } else if user.requestStatus == "RECEIVED" {
                                Text("待确认")
                                    .font(.system(size: 13))
                                    .foregroundColor(.orange)
                            } else if addingUserId == user.id {
                                ProgressView().controlSize(.small)
                            } else {
                                Button("添加") {
                                    Task { await addFriend(userId: user.id) }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        Divider().padding(.leading, 72)
                    }
                }
                .padding(.top, 16)
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView("搜索中...")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private func sectionRow(icon: String, iconColor: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(iconColor)
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .background(Color(.systemBackground))
        }
        .buttonStyle(.plain)
    }

    private var personPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(UIColor.systemGray5))
            .frame(width: 44, height: 44)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(.gray)
            )
    }

    private func search() async {
        guard !searchText.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        do {
            searchResults = try await FriendService.shared.searchUsers(query: searchText)
        } catch {
            print("搜索失败: \(error)")
        }
    }

    private func handleScannedUser(userId: String) async {
        guard let currentUserId = authManager.currentUser?.id else {
            alertMessage = "当前用户信息无效"
            return
        }
        if userId == currentUserId {
            alertMessage = "不能扫描自己的二维码"
            return
        }

        do {
            let user = try await FriendService.shared.getUserById(userId)
            let item = UserSearchResult(
                id: user.id,
                username: user.username,
                nickname: user.nickname,
                avatar: user.avatar,
                role: user.role,
                isFriend: false,
                requestStatus: "NONE"
            )
            searchResults = [item]
            searchText = user.username
        } catch {
            alertMessage = "无法识别该好友二维码"
        }
    }

    private func addFriend(userId: String) async {
        addingUserId = userId
        defer { addingUserId = nil }
        do {
            let response: APIResponse<FriendRequestResult> = try await FriendService.shared.sendFriendRequestWithResult(toUserId: userId)
            if let result = response.data {
                if result.autoAccepted == true {
                    acceptedRequests.insert(userId)
                    IMNavigationHelper.notifyFriendAdded()
                    alertMessage = "已自动添加为好友"
                } else {
                    sentRequests.insert(userId)
                    alertMessage = "好友申请已发送"
                }
            } else {
                sentRequests.insert(userId)
                alertMessage = "好友申请已发送"
            }
        } catch {
            let errorMsg = "\(error)"
            if errorMsg.contains("已经是好友") || errorMsg.contains("already friends") {
                acceptedRequests.insert(userId)
                IMNavigationHelper.notifyFriendAdded()
                alertMessage = "对方已是你的好友"
            } else if errorMsg.contains("已有待处理") {
                sentRequests.insert(userId)
                alertMessage = "已有待处理的好友申请"
            } else {
                alertMessage = "添加好友失败"
                print("添加好友失败: \(error)")
            }
        }
    }
}
