//
//  FriendListView.swift
//  pinghu12250
//
//  通讯录左侧列表 - 仿微信 iPad 通讯录
//

import SwiftUI

struct FriendListView: View {
    @EnvironmentObject var imCoordinator: IMCoordinator
    @Binding var selection: ContactSelection
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.messageSecondaryText)
                    .font(.system(size: 14))
                TextField("搜索联系人", text: $searchText)
                    .font(.system(size: 14))
            }
            .padding(8)
            .background(Color(hex: "F5F5F5"))
            .cornerRadius(8)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    // 功能菜单区
                    menuSection

                    // 分隔
                    Rectangle()
                        .fill(Color(hex: "F5F5F5"))
                        .frame(height: 8)

                    // 好友列表
                    friendSection
                }
            }
            .background(Color.white)
        }
        .task {
            await imCoordinator.refreshAll()
        }
    }

    // MARK: - 功能菜单区

    private var menuSection: some View {
        VStack(spacing: 0) {
            menuItem(
                icon: "person.badge.plus",
                iconColor: .orange,
                iconBg: Color.orange.opacity(0.1),
                title: "添加好友",
                selection: .addFriend
            )
            menuItem(
                icon: "person.2",
                iconColor: .blue,
                iconBg: Color.blue.opacity(0.1),
                title: "新的朋友",
                badge: imCoordinator.pendingRequestCount,
                selection: .newFriends
            )
            menuItem(
                icon: "brain.head.profile",
                iconColor: .purple,
                iconBg: Color.purple.opacity(0.1),
                title: "AI 老师",
                selection: .aiTeachers
            )
        }
    }

    private func menuItem(
        icon: String,
        iconColor: Color,
        iconBg: Color,
        title: String,
        badge: Int = 0,
        selection target: ContactSelection
    ) -> some View {
        let isSelected = selection == target
        return Button {
            selection = target
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
                    .frame(width: 40, height: 40)
                    .background(iconBg)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.messagePrimaryText)

                Spacer()

                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "C7C7CC"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? Color.appPrimary.opacity(0.1) : Color.white)
        }
        .overlay(
            Rectangle()
                .fill(Color(hex: "F0F0F0"))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    // MARK: - 好友列表

    private var friendSection: some View {
        VStack(spacing: 0) {
            // 好友组标题
            HStack {
                Text("好友")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.messageSecondaryText)
                Spacer()
                Text("\(filteredFriends.count)人")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "C7C7CC"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "F5F5F5"))

            // 好友行
            ForEach(filteredFriends) { friend in
                let isSelected = selection == .friend(friend)
                ContactRow(
                    name: friend.displayName,
                    avatar: friend.avatar,
                    role: friend.role.displayName,
                    isSelected: isSelected
                )
                .onTapGesture {
                    selection = .friend(friend)
                }
            }

            if filteredFriends.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 32))
                        .foregroundColor(Color(hex: "C7C7CC"))
                    Text("暂无好友")
                        .font(.system(size: 14))
                        .foregroundColor(.messageSecondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }

    private var filteredFriends: [User] {
        if searchText.isEmpty {
            return imCoordinator.friends
        }
        return imCoordinator.friends.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.username.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - 联系人行（保留复用）

struct ContactRow: View {
    let name: String
    let avatar: String?
    let role: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            avatarView

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .appPrimary : .messagePrimaryText)
                Text(role)
                    .font(.system(size: 13))
                    .foregroundColor(.messageSecondaryText)
            }
            Spacer()
        }
        .padding(12)
        .background(isSelected ? Color.appPrimary.opacity(0.15) : Color.white)
        .overlay(
            Rectangle()
                .fill(Color(hex: "F0F0F0"))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    @ViewBuilder
    private var avatarView: some View {
        if let avatar, let url = avatarURL(avatar) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                placeholderAvatar
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            placeholderAvatar
        }
    }

    private var placeholderAvatar: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(hex: "E5E7EB"))
            .frame(width: 44, height: 44)
            .overlay(
                Text(String(name.prefix(1)))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(hex: "9CA3AF"))
            )
    }

    private func avatarURL(_ path: String) -> URL? {
        if path.hasPrefix("http") {
            return URL(string: path)
        }
        return URL(string: APIConfig.baseURL + path)
    }
}
